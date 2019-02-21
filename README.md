# RubyCompiler
This is a Tiny Compiler programmed with Ruby language and FXRuby.

By the way, this Tiny Compiler uses two executions threads. One synchronizes the movement of the code area and line number
and second deals with the execution stream; this thread stop the execution on write instruccions in order to give time to the
users to write their inputs and continue with the execution. Both threads work better on Linux than Windows, but they tend to crash
because of the FXRuby library (As far as I know).

If you have a solution for these crashes, please leave a comment or send a pull request.
