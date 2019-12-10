# C++ to GDScript ports

The purpose of this repository is to translate built-in engine C++ classes back 
into pure GDScript, if possible.

List of ported classes:
- [`RemoteTrasform2D`](scene/2d/remote_transform_2d.gd)
- [`Label`](scene/gui/label.gd)

Based on these classes you can:
- adapt them to your own needs via script;
- develop plugins inspired by Godot's built-in functionallity;
- if you feel like reimplemeting the existing functionallity via script would
promote faster prototyping of a major feature to be integrated back to C++.

## Contributing

When adding new classes, the directory structure should ideally represent 
the Godot Engine source code tree.

At the top of a script, please add the following tags as comments:

```gdscript
# port author: You
# license: MIT
# source: https://github.com/godotengine/godot/blob/c868baf65/scene/2d/remote_transform_2d.cpp
```
