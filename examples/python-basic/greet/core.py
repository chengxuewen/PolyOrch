"""greet package core: the breakpoint targets for cross-file F5 (my-code)
and stdlib stepping (needs JUST_MY_CODE OFF -- library code by debugpy's
judgement)."""
import json
import os


def greet(name):
    message = "hello, " + name + "!"
    return message            # breakpoint candidate #1 (cross-file)


def main():
    who = os.environ.get("POLYORCH_WHO", "python")
    for _ in range(3):        # breakpoint candidate #2
        print(greet(who))
    print(json.dumps({"who": who}))   # steps into json/__init__.py dumps
                                      # when justMyCode is false
