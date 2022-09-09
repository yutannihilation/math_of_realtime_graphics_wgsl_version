# WGSL practice

## Usage

``` sh
cargo run -- path/to/frag_shader.wgsl

# change width and height
cargo run -- -w 400 -h 600 path/to/frag_shader.wgsl
```

### Keys

* <kbd>Esc</kbd>: exit
* <kbd>Space</kbd>: reset time and frame
* <kbd>↑</kbd>: increment channel
* <kbd>↓</kbd>: decrement channel

## Original book

[巴山竜来「リアルタイムグラフィックスの数学―GLSLではじめるシェーダプログラミング」](https://gihyo.jp/book/2022/978-4-297-13034-3)

## References

* Rust source code related to wgpu is based on [Learn WGPU](https://sotrh.github.io/learn-wgpu/), which is licensed under the MIT license.
* WGSL source code is based on [巴山竜来「リアルタイムグラフィックスの数学―GLSLではじめるシェーダプログラミング」](https://gihyo.jp/book/2022/978-4-297-13034-3).
