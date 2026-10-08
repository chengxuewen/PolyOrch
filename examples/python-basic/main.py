"""python-basic example body: breakpoint-friendly call structure.

The greet() return line and the loop body are the two F5 stop candidates;
POLYORCH_WHO arrives through the run() ENVS injection point (-E env).
"""
import os


def greet(name):
    message = "hello, " + name + "!"
    return message            # breakpoint candidate #1


def main():
    who = os.environ.get("POLYORCH_WHO", "python")
    for _ in range(3):        # breakpoint candidate #2
        print(greet(who))


if __name__ == "__main__":
    main()
