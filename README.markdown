# 1brc
This is a recreation of the challenge [1brc](https://github.com/gunnarmorling/1brc) proposed by Gunnar in Common Lisp. I am no expert and so this is probably not the best code. I have also ignored the "no external dependencies" rule because I needed to call mmap and babel (for utf8 encoding).

## Results

This runs in **~20** seconds in a **Intel i7-9750H** with **16GB** of RAM. It has 12 cores so if you want to re-create it, you should change it according to your CPU.

## Sources
- The original repo: [https://github.com/gunnarmorling/1brc](https://github.com/gunnarmorling/1brc)
- Python implementation: [https://github.com/ifnesi/1brc](https://github.com/ifnesi/1brc)
- A blog with cool notes on speed: [https://blog.kingcons.io/posts/Going-Faster-with-Lisp.html](https://blog.kingcons.io/posts/Going-Faster-with-Lisp.html)

## Running
You can use `make build` or `make run` to do what it says. You can also load the project with quicklisp in a repl and hack away at it. To generate the `data/measurements.txt` you need to run `createMeasurements.py 100_000_000`. This will create a file with a billion (100.000.000) entries.
