import asyncio
from dotenv import load_dotenv
from claude_agent_sdk import ( 
    AgentDefinition, ClaudeSDKClient, ClaudeAgentOptions, AssistantMessage, ResultMessage,
)
from claude_agent_sdk.types import StreamEvent
from utils import display_message

load_dotenv()

PROMPTS_DIR = "prompts"

# Inactivity timeout: how long to wait with NO messages before considering
# the response stalled. Must be generous because the model can spend several
# minutes generating a single large Write tool call (e.g. a 500-line file)
# with zero intermediate messages during token generation.
INACTIVITY_TIMEOUT = 300  # 5 minutes of silence = stalled

# How many times to automatically retry after a stall before switching strategy.
MAX_RETRIES = 2

def load_prompt(filename: str) -> str:
    """Load a prompt from the prompts directory."""
    prompt_path = f"{PROMPTS_DIR}/{filename}"
    with open(prompt_path, "r") as f:
        return f.read().strip()


async def drain_after_interrupt(client: ClaudeSDKClient):
    """Drain any remaining messages after sending an interrupt."""
    try:
        async with asyncio.timeout(15):
            async for message in client.receive_response():
                if isinstance(message, AssistantMessage):
                    display_message(message)
                elif isinstance(message, ResultMessage):
                    break
    except (asyncio.TimeoutError, Exception):
        pass


CONTINUE_PROMPT = (
    "The previous request stalled — some tool calls may have hung. "
    "Do NOT retry any web fetches. Instead, proceed to complete ALL remaining "
    "deliverables RIGHT NOW using the information you have already gathered "
    "combined with your own knowledge. You MUST create every file and every "
    "code example defined in the output format — never leave files missing or "
    "directories empty. Use your own knowledge to fill any gaps from failed "
    "research. Mark those sections as 'based on general knowledge'."
)


async def send_and_receive(client: ClaudeSDKClient, message: str, timeout: int = INACTIVITY_TIMEOUT) -> bool:
    """Send a query and receive the response with an INACTIVITY timeout.
    
    The timeout resets every time a new message arrives. This means:
    - A response that takes 10 minutes but streams messages every 30s: OK
    - A response that goes silent for 90s (no messages): considered stalled
    
    Returns True if the response completed normally, False if it stalled.
    On stall, interrupts the request and drains remaining messages.
    """
    await client.query(message)
    try:
        # Get the async iterator so we can pull one message at a time
        # without re-entering the generator on each iteration.
        response_iter = client.receive_response().__aiter__()
        while True:
            try:
                # Wait for the next message, but only up to `timeout` seconds.
                # If no message arrives within that window, the agent is stalled.
                msg = await asyncio.wait_for(response_iter.__anext__(), timeout=timeout)
            except StopAsyncIteration:
                # Stream ended normally (shouldn't happen without ResultMessage, but handle it)
                return True
            except asyncio.TimeoutError:
                print(f"\n\033[33m⚠ No activity for {timeout}s — response appears stalled.\033[0m")
                try:
                    await client.interrupt()
                except Exception:
                    pass
                await drain_after_interrupt(client)
                return False

            # Process the message — any message type resets the inactivity timer.
            if isinstance(msg, AssistantMessage):
                display_message(msg)
            elif isinstance(msg, ResultMessage):
                return True  # Done — response completed successfully
            elif isinstance(msg, StreamEvent):
                pass  # Heartbeat — model is generating tokens, just reset timer
    except Exception as e:
        print(f"\n\033[31m✗ Error during response: {e}\033[0m\n")
        return True  # Don't retry on non-timeout errors


async def query_with_retry(client: ClaudeSDKClient, user_input: str):
    """Send a query with automatic retry and graceful continuation on stall.
    
    Strategy:
    1. Try the original query up to MAX_RETRIES + 1 times.
       The inactivity timeout lets active work (research, writing) take as long
       as it needs — only stalls (hung tool calls) trigger a retry.
    2. If all retries stall, send escalating "continue with what you have" messages.
    3. As a last resort, ask the agent to produce output from built-in knowledge.
    """
    # Phase 1: Try the original query with retries
    for attempt in range(MAX_RETRIES + 1):
        if attempt > 0:
            print(f"\033[33m⟳ Retry attempt {attempt}/{MAX_RETRIES}...\033[0m\n")
        
        if await send_and_receive(client, user_input):
            return  # Success

    # Phase 2: Original query keeps stalling — switch to "continue" prompts.
    # Each continue prompt also gets retries. We escalate the urgency.
    continue_messages = [
        CONTINUE_PROMPT,
        "You are still stalling. Do NOT use WebFetch or WebSearch. Focus on "
        "writing all remaining output files using your own knowledge. Every file "
        "and code example from the output format must be created with real content.",
        "Stop all research. Use only the Write tool to create any remaining "
        "deliverable files. Fill them with useful content from your own knowledge. "
        "Do not leave anything empty or missing.",
    ]

    for i, continue_msg in enumerate(continue_messages):
        print(f"\033[33m⟳ Asking agent to continue with available information "
              f"(attempt {i + 1}/{len(continue_messages)})...\033[0m\n")

        for retry in range(MAX_RETRIES + 1):
            if retry > 0:
                print(f"\033[33m⟳ Retry {retry}/{MAX_RETRIES}...\033[0m\n")

            if await send_and_receive(client, continue_msg):
                return  # Success

    # Last resort: ask the agent to create all deliverables from its own knowledge.
    print("\033[33m⟳ Final attempt — creating deliverables from built-in knowledge...\033[0m\n")
    last_resort = (
        f"All web research has failed. Using ONLY the Write tool and your own "
        f"built-in knowledge, please create ALL the output files required for "
        f"this request. Write complete, useful content — not placeholders. "
        f"Mark sections as 'based on general knowledge' where research would "
        f"have provided better data. Here is the original request:\n\n{user_input}"
    )
    if not await send_and_receive(client, last_resort):
        print("\033[33m⚠ Could not get a complete response, but partial output "
              "may have been displayed above.\033[0m\n")


async def main():

    main_agent_prompt = load_prompt("main_agent.md")
    docs_researcher_prompt = load_prompt("docs_researcher.md")
    repo_analyzer_prompt = load_prompt("repo_analyzer.md")
    web_researcher_prompt = load_prompt("web_researcher.md")

    agents = {
        "docs_researcher" : AgentDefinition(
            description="Finds and extracts information from official documentation sources.",
            prompt = docs_researcher_prompt,
            tools = ["WebSearch", "WebFetch"],
            model = "haiku"
        ),
        "repo_analyzer" : AgentDefinition(
            description="Analyzes code repositories for structure, examples, and implementation details.",
            prompt = repo_analyzer_prompt,
            tools = ["WebSearch", "WebFetch"],
            model = "haiku"
        ),
        "web_researcher" : AgentDefinition(
            description="Finds articles, videos, and community content.",
            prompt = web_researcher_prompt,
            tools = ["WebSearch", "WebFetch"],
            model = "haiku"
        ),
    }


    # tools, subagents
    options = ClaudeAgentOptions(
        system_prompt=main_agent_prompt,
        setting_sources=["user", "project"],
        allowed_tools=["Skill", "Task", "Write", "Bash", "WebSearch", "WebFetch"], # read-only tools like read, Grep, Glob are allowed by default
        model="sonnet",
        agents=agents,
        include_partial_messages=True,  # Stream token-level events as heartbeats for inactivity detection
    )

    async with ClaudeSDKClient(options=options) as client:
        print("Starting conversation session.")
        print("Type 'exit' to quit\n") 
        while True:
            user_input = input('\033[1m' + 'You' + '\033[0m'+': ')
            print('')
            if user_input.lower() == 'exit':
                break
            await query_with_retry(client, user_input)

asyncio.run(main())
