# GDScript Style Guide Summary

## Core Principles
- Write clean, readable code with consistent formatting
- Prioritize consistency within projects and teams
- Modular, extensible, maintanable code is key

## Formatting Standards
- Use UTF-8 encoding, LF line endings
- Use tabs for indentation (not spaces)
- Keep lines under 100 characters (preferably 80)
- Use trailing commas in arrays, dictionaries, enums
- Add blank lines: 2 between class_name/extend, declarations, functions/classes
- One statement per line (except ternary operator)
- Use parentheses for multiline expressions
- Avoid unnecessary parentheses

## Naming Conventions
- Files: snake_case.gd
- Classes/Nodes: PascalCase
- Functions/Variables: snake_case
- Signals: past tense (snake_case)
- Constants/Enum members: CONSTANT_CASE
- Enums: PascalCase
- Private members: prefix with underscore (_private_var)

## Syntax & Typing
- Prefer `and`/`or`/`not` over `&&`/`||`/`!`
- Use double quotes for strings (single only when fewer escapes needed)
- Include leading/trailing zeros in floats (0.5 not .5)
- Use underscores in large numbers (1_000_000)
- Use static typing with `var name: Type` or `:=` inference
- For get_node(), explicitly type or use `as` casting

## Comments
- Use ## for documentation comments
- Use # for regular comments (add space after #)
- Prefer standalone comments over inline ones

## Best Practices
- Declare local variables close to first use
- Don't declare member variables only used locally
- Use parentheses around complex boolean expressions
- Wrap long conditions/expressions across multiple lines with 2-level indentation
- Place operators at start of continuation lines for conditions
