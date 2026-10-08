"""t-python-dap debuggee: the breakpoint line is located dynamically by
probe.py (parsed from this source, never hardcoded)."""


def work():
    marker = 42  # breakpoint line: probed dynamically from this file
    return marker


if __name__ == "__main__":
    print(work())
