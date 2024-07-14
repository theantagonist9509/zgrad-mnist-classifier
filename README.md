# MNIST Classifier

MNIST classifier implemented and trained from scratch in Zig

![interact.gif](https://github.com/theantagonist9509/zgrad-mnist-classifier/blob/main/interact.gif)

## Build Instructions

Use Zig 0.12 for building.

### Train

This build artifact requires no dependencies.

To train a model, run `zig build train`. This will train a model and serialize it as a binary named `classifier`.

The model architecture, learning hyperparameters, number of epochs, output path, etc. can be configured in `src/train.zig`.

**If there already exists a file at the model output path, then it will be loaded and fine-tuned instead of being trained from scratch.**

### Interact

This build artifact requires raylib (headers and library), raygui.h, libGL, and libX11.

https://github.com/theantagonist9509/zgrad-mnist-classifier/blob/436c487dd4883969a668aed4b1d48c1352a48a52/build.zig#L37-L53

To interact with the model, run `zig build interact`. This will open an interactive window with a paint tool and a bar chart of the model's (`classifier` by default) predictions.

The model input path can be configured in `src/interact.zig`;

## License (MIT)

Copyright (c) 2024 Tejas T. Singh

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
