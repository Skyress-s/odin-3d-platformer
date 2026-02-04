# Running project
- Need to have odin lang installed. https://odin-lang.org/
- 'odin run src/'

# Packaging project
There is a separate odin project in ./build_src/ that builds, packages and zips the project.
- Need to have odin lang installed. https://odin-lang.org/
- 'odin run build_src/'
- Should take about 3s. Afterwards should have a new *.zip folder containing the game. Ready to be shared!

# Dev notes

to get all target platform we can build for: odin build src/ -target:?

to actually build for that target odin build src/ -target:windows_amd64 for example
