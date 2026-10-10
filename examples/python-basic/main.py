"""python-basic example entry: thin launcher for the greet package.

POLYORCH_WHO arrives through the run() ENVS injection point (-E env).
The F5 stop candidates live in greet/core.py; its json.dumps call is the
stdlib-stepping demo (JUST_MY_CODE OFF).
"""
from greet.core import main


if __name__ == "__main__":
    main()
