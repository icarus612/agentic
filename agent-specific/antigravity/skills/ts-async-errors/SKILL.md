# Goal
Write async controllers/functions with consistent error handling.

# Instructions
1. Do not wrap every single await in a try/catch.
2. Use a higher-order function (e.g., `catchAsync`) for Express/Fastify routes.
3. Ensure structured logging (JSON) is used for the error output, including the stack trace.