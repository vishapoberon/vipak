# Vipak Local Build System

Vipak provides a powerful local build system for Oberon projects that automatically handles dependency resolution, fetching, and compilation. This allows you to build complex projects with external dependencies using a simple `vipak --local` command.

## Quick Start

### Initialize a New Project

```bash
vipak --init
```

This creates:
- `vipak.json` - Project configuration file
- `src/myproject.Mod` - Template Oberon module

### Build Your Project

```bash
vipak --local
```

This will:
1. Resolve and fetch all dependencies
2. Compile dependencies in dependency order
3. Build your project sources

## Project Structure

```
myproject/
├── vipak.json          # Project configuration
├── src/                # Your source files
│   └── myproject.Mod
├── build/              # Build output (created automatically)
│   └── deps/           # Downloaded dependencies
└── deps.dot            # Dependency graph (for visualization)
```

## vipak.json Format

The `vipak.json` file defines your project configuration:

```json
{
    "Package": "project-name",
    "Author": "Your Name", 
    "License": "GPL-3",
    "Version": "0.1",
    "Remote": {
        "type": "git",
        "path": "https://codeberg.org/yourname/project",
        "tag": "0.1"
    },
    "Dependencies": {
        "dependency1": "version",
        "dependency2": "version"
    },
    "Build": [
        {
            "Command": "voc -m",
            "File": "src/main.Mod"
        }
    ]
}
```

### Required Fields

- **Package**: Project name
- **Author**: Author name
- **Version**: Project version
- **Build**: Array of build steps

### Optional Fields

- **License**: Software license
- **Remote**: Git repository information (for publishing)
- **Dependencies**: External dependencies to fetch and build

## Examples

### 1. Simple Project with Git Dependencies

```json
{
    "Package": "myproject",
    "Author": "Your Name",
    "License": "GPL-3",
    "Version": "0.1",
    "Remote": {
        "type": "git",
        "path": "https://codeberg.org/yourname/myproject",
        "tag": "0.1"
    },
    "Dependencies": {
        "opts": "0.1",
        "Internet": "0.1"
    },
    "Build": [
        {
            "Command": "voc -m",
            "File": "src/myproject.Mod"
        }
    ]
}
```

### 2. Multiple Build Targets

Build both a main program and a test program:

```json
{
    "Package": "myproject",
    "Author": "Your Name", 
    "License": "GPL-3",
    "Version": "0.1",
    "Remote": {
        "type": "git",
        "path": "https://codeberg.org/yourname/myproject",
        "tag": "0.1"
    },
    "Dependencies": {
        "opts": "0.1",
        "Internet": "0.1"
    },
    "Build": [
        {
            "Command": "voc -m",
            "File": "src/myproject.Mod"
        },
        {
            "Command": "voc -m", 
            "File": "src/test.Mod"
        }
    ]
}
```

### 3. Mixed Dependency Sources

Some dependencies from Git repositories, others from HTTP sources:

```json
{
    "Package": "myproject",
    "Author": "Your Name",
    "License": "GPL-3", 
    "Version": "0.1",
    "Remote": {
        "type": "git",
        "path": "https://codeberg.org/yourname/myproject",
        "tag": "0.1"
    },
    "Dependencies": {
        "time": "0.1",
        "strutilstest": "0.1"
    },
    "Build": [
        {
            "Command": "voc -m",
            "File": "src/myproject.Mod"
        }
    ]
}
```

*Note: `time` might come from a Git repository while `strutilstest` comes from HTTP sources, depending on how they're configured in the package tree.*

### 4. Library Project (No Executable)

For projects that only build library modules:

```json
{
    "Package": "mylib",
    "Author": "Your Name",
    "License": "MIT",
    "Version": "0.2",
    "Build": [
        {
            "Command": "voc -s",
            "File": "src/MyLib.Mod"
        },
        {
            "Command": "voc -s", 
            "File": "src/MyLibUtils.Mod"
        }
    ]
}
```

## Build Commands

### Common voc Options

- `voc -m file.Mod` - Compile main program (creates executable)
- `voc -s file.Mod` - Compile library module (creates .sym file)
- `voc -c file.Mod` - Compile to object file only

### Custom Build Commands

You can use any build command, not just `voc`:

```json
"Build": [
    {
        "Command": "make",
        "File": "Makefile"
    },
    {
        "Command": "cp src/config.txt",
        "File": "config/default.txt"
    }
]
```

## Dependency Resolution

Vipak automatically:

1. **Resolves transitive dependencies** - If A depends on B, and B depends on C, all three are built
2. **Handles dependency order** - Builds dependencies before dependents
3. **Avoids duplicates** - Each dependency is built only once
4. **Supports multiple sources** - Git repositories, HTTP/HTTPS file downloads
5. **Creates build graph** - Generates `deps.dot` for visualization

### Viewing Dependency Graph

```bash
# Generate PNG image of dependency graph
dot -Tpng deps.dot > deps.png
```

## Build Process

When you run `vipak --local`:

1. **Parse vipak.json** - Read project configuration
2. **Resolve dependencies** - Build complete dependency tree
3. **Create build directory** - `build/` for outputs
4. **Fetch dependencies** - Download from Git/HTTP sources
5. **Build dependencies** - Compile in correct order
6. **Build project** - Compile your source files

### Build Output

```
myproject/
├── build/
│   ├── deps/                    # Dependency sources
│   │   └── domain.com/project/
│   │       └── src/
│   ├── myproject                # Your executable
│   └── *.sym                    # Symbol files
└── deps.dot                     # Dependency graph
```

## Example Usage Session

```bash
# Initialize new project
$ vipak --init
Project initialized! You can now:
  1. Edit src/myproject.Mod with your code
  2. Edit vipak.json to configure build settings  
  3. Run 'vipak --local' to build the project

# Edit your source file
$ vim src/myproject.Mod

# Build the project
$ vipak --local
Building local project from: vipak.json
Building project: myproject v0.1
Created build directory: build

resolving dependencies for local project...
Found 2 direct dependencies
Resolving: opts
Resolving: Internet
 done! (:

dependency graph:
-----------------
digraph dependencies {
  opts -> strutils
  Internet -> strutils
}
-----------------

dependencies will be installed in the following order:
strutils
opts
Internet

Fetching: strutils
*** GIT: Cloning to: 'build/deps/codeberg.org/vishapoberon/strutils'
*** GIT: Clone successful
Building dependency: strutils
Build successful

Fetching: opts  
*** GIT: Cloning to: 'build/deps/codeberg.org/vishapoberon/opts'
*** GIT: Clone successful
Building dependency: opts
Build successful

Fetching: Internet
*** HTTP: fetchFiles called
getting http://example.com/Internet.Mod
Build successful

All dependencies processed!
Building project: myproject
Executing: voc -m ../src/myproject.Mod
../src/myproject.Mod  Compiling myproject.  Main program.  608 chars.
Build completed successfully!

# Run your program
$ ./build/myproject
Hello from myproject!
This project was built using vipak --local
```

## Troubleshooting

### Common Issues

**"symbol file of imported module not found"**
- Dependency wasn't built successfully
- Check dependency is listed in vipak.json
- Verify dependency exists in package tree

**"Failed to change to build directory"**
- Build directory creation failed
- Check file permissions
- Ensure sufficient disk space

**"Warning: Build failed with code: X"**
- Dependency compilation failed
- Check dependency source code
- Verify voc can compile the dependency

### Debug Tips

1. **Check dependency graph**: Use `dot -Tpng deps.dot > deps.png`
2. **Verify downloads**: Look in `build/deps/` for source files
3. **Test dependencies manually**: Try building dependencies with `voc` directly
4. **Check build order**: Dependencies should build before your project

### Getting Help

- Check the package tree for dependency definitions
- Verify dependency versions are available
- Ensure all required tools (`voc`, `git`) are installed
- Check network connectivity for HTTP/Git downloads

## Advanced Features

### Package Tree Integration

Vipak integrates with the global package tree for dependency resolution. Dependencies are resolved from:

1. **Local package tree** - `~/.vipak/vipatsar/`
2. **Remote package tree** - Default: https://codeberg.org/vishapoberon/vipatsar

### Custom Package Trees

You can override the package tree location:

```bash
vipak --tree /path/to/custom/tree --local
```

### Offline Builds

Once dependencies are downloaded to `build/deps/`, builds work offline. Delete the build directory to force re-downloading dependencies.

---

## Contributing

To contribute to vipak or report issues, visit: https://codeberg.org/vishapoberon/vipak