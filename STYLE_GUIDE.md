# D Style Guide

## Design Philosophy

Write imperative, direct code. Minimize indirection, abstraction layers, and unnecessary generalization. Prefer straightforward control flow over clever patterns. Code should read top-to-bottom with minimal jumping between definitions.

- **No indirection**: Avoid wrapping simple operations in helper abstractions. Call things directly.
- **No over-abstraction**: Do not create interfaces, mixins, or template layers unless they eliminate significant duplication.
- **Imperative flow**: Use explicit loops, conditionals, and assignments. Avoid range-based pipelines or functional chains when a `for`/`foreach` loop is clearer.
- **Flat is better**: Prefer early returns to reduce nesting. Keep function bodies shallow.

## Naming

### General Rules
- **PascalCase** for types: classes, structs, enums, aliases — `TurntWindow`, `SplayChild`, `BrowseView`
- **camelCase** for everything else: variables, functions, methods, parameters — `vinylAngle`, `onDragBegin`, `collectAudio`
- **camelCase** for constants and enum manifest constants — `musicDir`, `cssPath`, `audioExts`, `pad`
- **Never declare SNAKE_CASE** identifiers. UPPER_CASE names from external libraries (e.g. `STYLE_PROVIDER_PRIORITY_APPLICATION`) are acceptable only as imports, never as declarations in our code.

### Specific Conventions
- **Return variables**: Name the return variable `ret` when a function builds and returns a value:
  ```d
  string[] collectAudio(string dir, SpanMode mode = SpanMode.depth)
  {
      string[] ret;
      if (!exists(dir) || !isDir(dir))
          return ret;
      foreach (entry; dirEntries(dir, mode))
          if (entry.isFile && isAudioFile(entry.name))
              ret ~= entry.name;
      ret.sort();
      return ret;
  }
  ```
- **Private backing fields**: Prefix with underscore only when a public accessor exists for the same name — `_instance` backing `instance()`.
- **Boolean names**: Use affirmative adjectives or participles — `playing`, `hovered`, `animating`, `splayed`. Avoid `is`/`has` prefixes on fields; reserve those for methods when needed.
- **No trivial getters**: If a getter simply returns a private field with no logic, make the field public instead. Wrapping `return hovered;` in `isHovered()` is unnecessary indirection.
- **Property functions use lambda syntax**: Short property-style functions that return a single expression should use `=>` on an indented next line:
  ```d
  // Good
  bool hasSplayChildren()
      => splayChildren.length > 0;

  // Bad
  bool hasSplayChildren()
  {
      return splayChildren.length > 0;
  }
  ```

## Types

### Explicit Types Over `auto`
Always spell out the type. `auto` hides intent and makes code harder to read at a glance.

```d
// Good
Adjustment adj = view.scrolled.getVadjustment();
GestureDrag scrollDrag = new GestureDrag();
TurntWindow win = TurntWindow.instance;
string ext = path.extension.toLower();

// Bad
auto adj = view.scrolled.getVadjustment();
auto scrollDrag = new GestureDrag();
auto win = TurntWindow.instance;
```

`auto` is acceptable only when:
- The type is an internal compiler-generated type (e.g. Voldemort types from ranges)
- The type name is excessively long and adds no clarity

### `@property` vs `ref`
- **Avoid `@property`**. If a member needs both read and write access, return it by `ref` from a method.
- If only read access is needed, use a regular method (no `ref`, no `@property`).
  ```d
  // Good — read/write via ref
  ref int count() { return _count; }

  // Good — read-only
  int count() { return _count; }

  // Bad
  @property int count() { return _count; }
  @property void count(int v) { _count = v; }
  ```

### Casts
- Use `cast(Type)` directly. Do not wrap casts in helper functions.
- Prefer `cast(int)` over `.to!int` for simple numeric conversions in hot paths.

## Operators and Spacing

### No Spaces Around `~` and `..`
```d
// Good
result ~= syms[i];
string payload = artist~"|"~album;
foreach (i; 0..count)
string path = buildPath(dir, name~ext);

// Bad
result ~= syms[i];   // ~= is fine, it's an assignment operator
string payload = artist ~ "|" ~ album;
foreach (i; 0 .. count)
```

Note: `~=` is an assignment operator and follows assignment spacing rules (space before, no space between `~` and `=`).

### Standard Operator Spacing
- **Spaces around** binary arithmetic, comparison, logical, and assignment operators: `a + b`, `x == y`, `a && b`, `x = 5`
- **No space** after unary operators: `!flag`, `-x`, `*ptr`, `&val`
- **No space** before semicolons, commas, or closing parens
- **One space** after commas, semicolons in `for` headers, and colons in slices only when clarity demands it

## Brace Style

### Allman (BSD) Style — Default
Opening brace on its own line for all declarations: functions, classes, structs, `if`, `else`, `for`, `foreach`, `while`, `switch`.

```d
class ScrollState
{
    void onDragBegin(double x, double y)
    {
        coasting = false;
        Adjustment adj = view.scrolled.getVadjustment();
        if (adj !is null)
        {
            dragStartScroll = adj.value;
            double contentY = adj.value + y - 8;
        }
    }
}
```

### K&R Style — Only for Inline Delegates
When a delegate is passed inline as a callback argument, the opening brace goes on the same line as the `delegate` keyword:

```d
playPauseBtn.connectToggled(delegate void() {
    if (queue !is null)
    {
        if (playPauseBtn.active)
            queue.resume();
        else
            queue.pause();
    }
});

cursorTracker.connectMotion(delegate(double, double y) {
    state.cursorY = y;
});
```

Note: The body of the delegate still uses Allman for its own `if`/`else`/`for` blocks.

### Braceless Statements
Single-statement bodies after `if`, `else`, `foreach`, `while`, and `for` do not require braces **only when the body is a single simple statement** (an assignment, a call, `return`, `break`, or `continue`). Place the statement on the next line, indented:

```d
if (adj !is null)
    dragStartScroll = adj.value;

foreach (e; audioExts)
    if (ext == e)
        return true;
```

**When the body itself contains another control-flow statement** (`if`, `for`, `foreach`, `while`, or a block), always use braces on the outer statement. This avoids deeply nested braceless chains that are hard to follow:

```d
// Good — outer foreach gets braces because its body is an if
foreach (ref alb; ai.albums)
{
    if (alb.name == album)
    {
        albInfo = &alb;
        break;
    }
}

// Bad — nested single-line statements masquerading as simple
foreach (ref alb; ai.albums)
    if (alb.name == album)
    {
        albInfo = &alb;
        break;
    }
```

Use braces when the body is more than one statement or when the condition + body together are complex enough to warrant visual grouping.

## Indentation and Formatting

- **4 spaces**, no tabs.
- **120-character** soft line limit. Break long lines at commas or after operators.
- **Single blank line** between function/method definitions.
- **No trailing whitespace**.
- **Access specifiers** (`private:`, `public:`) at class-body indentation level (no extra indent), with members indented one level below.

```d
class Foo : Bar
{
private:
    int x;

public:
    void doThing()
    {
        x = 5;
    }
}
```

## Imports

### Order
1. `std.*` (standard library)
2. Third-party / binding libraries (alphabetical by top-level package)
3. Project-local imports

### Style
- Use selective imports to keep the namespace clean: `import std.math : abs, cos, sin, PI;`
- One `import` per line. Group related selective imports from the same module on one line.
- Separate the three groups with a blank line.

```d
import std.math : abs, cos, fmin, sin, PI;
import std.string : indexOf, toUpper;

import cairo.context;
import cairo.global;
import gtk.drawing_area;

import turnt.queue;
import turnt.window;
```

## Module and File Structure

- One primary public class or a cohesive set of free functions per file.
- Module name matches file path: `turnt/catalogue/vinyl.d` → `module turnt.catalogue.vinyl;`
- Use `package.d` for public re-exports only.
- Mark internal helpers `private` at module level.

## Error Handling

- Use `try`/`catch` only around operations that can genuinely throw (file I/O, parsing).
- Catch `Exception`, not `Throwable`.
- Prefer returning sentinel values (`null`, empty string, `-1`) over throwing for expected failure cases.
- Empty catch blocks are acceptable for best-effort operations (e.g. loading optional cover art) but should be a conscious choice.

## Null Checks

- Always check nullable references before use: `if (adj !is null)`
- Use `is null` / `!is null`, never `== null`.

## Miscellaneous

- **No `@safe`, `@trusted`, `@nogc`, `nothrow`** annotations unless required by an API contract.
- **No `unittest` blocks** inline with production code; tests go in separate files if needed.
- **Avoid `scope` guards** (`scope(exit)`, etc.) when a simple try/finally or RAII pattern is clearer.
- **Enum manifest constants** are preferred over `immutable` for compile-time values: `enum pad = 8;`
- **String mixins and CTFE**: Avoid unless they provide a clear, measurable benefit.
