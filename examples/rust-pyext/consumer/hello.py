# The python consumer: imports the built extension module and asserts the
# API. PYTHONPATH is pointed at the module by the demo target.
import spine_py

assert spine_py.add(19, 23) == 42, spine_py.add(19, 23)
print("python:", spine_py.greet("consumer"), "| add(19,23) = 42")
