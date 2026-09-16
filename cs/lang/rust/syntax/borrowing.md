# Rust 的 Borrowing 与 Lifetime

本文讲解 Rust 中 borrowing 与 lifetime 的核心概念,它们是理解 Rust 内存安全保证的关键。

## Borrowing

(关于 borrowing 的内容将在此展开,目前我们先聚焦于 lifetime。)

## Lifetime

生命周期(lifetime)是 Rust 的核心概念之一,它让 Rust 无需垃圾回收器即可保证内存安全。lifetime 是一种编译期机制,用于告诉编译器 reference 在多长时间内有效,从而避免出现 dangling reference。lifetime 并不改变数据实际存活的时长;它描述的是 reference 与其所指向数据之间的关系。

### 为什么需要 Lifetime?

在 C/C++ 这类语言中,很容易产生 "dangling reference"——即指向已被释放数据的 reference。使用这类 reference 会导致未定义行为,常常引发崩溃或数据损坏。Rust 的 ownership 与 borrowing 规则能够避免其中许多问题,但当函数或 struct 持有 reference 时,编译器需要更多信息,才能保证这些 reference 不会比它们所指向的数据存活得更久。lifetime 标注正是提供这一关键信息的手段。

### 基本的 Lifetime 语法

lifetime 参数以单引号 `'` 开头,后接一个名称(通常是小写字母,例如 `'a`、`'b`、`'static`)。它们通常声明在尖括号内,与泛型类型参数类似。

```rust
// 'a 是一个 lifetime 参数
let r: &'a i32;
```

### Lifetime Elision(省略)规则

你或许会注意到,许多包含 reference 的 Rust 代码片段并没有显式写出 lifetime 标注。这是因为 Rust 编译器有一套 **lifetime elision(省略)规则**,能够在常见且无歧义的模式下推断出 lifetime。这让代码更简洁、更少冗余。

常见的 elision 规则包括:
1.  每个作为输入的 reference 参数各自获得一个独立的 lifetime 参数。
2.  如果恰好只有一个输入 lifetime 参数,那么该 lifetime 会被赋予所有输出 lifetime 参数。
3.  如果存在多个输入 lifetime 参数,但其中之一是 `&self` 或 `&mut self`,那么 `self` 的 lifetime 会被赋予所有输出 lifetime 参数。

当这些规则都不适用时,你必须显式标注 lifetime。

### 显式 Lifetime 标注:何时以及为何

当编译器无法通过 elision 规则无歧义地推断出 reference 之间的 lifetime 关系时,你需要手动添加 lifetime 标注。

#### 1. 函数签名中的 Lifetime

当一个函数接收 reference 作为参数,并返回一个可能与某个输入 reference 相关联的 reference 时,你必须标注 lifetime。

**示例:返回两个字符串 slice 中较长的一个**

```rust
// 该函数接收两个字符串 slice,二者都保证至少存活到 'a。
// 返回的字符串 slice 也保证至少存活到 'a。
// 这意味着返回的 reference 不能比任一输入 reference 存活得更久。
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() {
        x
    } else {
        y
    }
}

fn main() {
    let string1 = String::from("abcd");
    let string2 = "xyz";

    let result = longest(string1.as_str(), string2);
    println!("The longest string is {}", result);

    // 若缺乏恰当的 lifetime 管理,下面这个例子会导致编译期错误:
    // let result;
    // {
    //     let string3 = String::from("long string is long");
    //     result = longest(string1.as_str(), string3.as_str());
    // } // string3 在此处被 drop,若之后再使用 'result' 就会成为 dangling reference。
    // println!("The longest string is {}", result);
}
```
在 `longest` 函数中,`<'a>` 声明了一个 lifetime 参数。`x: &'a str`、`y: &'a str` 以及 `-> &'a str` 将该 lifetime 参数应用到参数和返回值上。这告诉编译器:返回的 reference 至少在 `x` 与 `y` 中*较短*的那个存活期内有效。

#### 2. Struct 定义中的 Lifetime

如果一个 struct 持有 reference,那么该 struct 实例的 lifetime 不能超过它所包含的任何一个 reference 的 lifetime。

**示例:持有一个字符串 slice 的 struct**

```rust
// ImportantExcerpt struct 的 lifetime 不能超过它所引用的 'part' 的 lifetime。
struct ImportantExcerpt<'a> {
    part: &'a str,
}

fn main() {
    let novel = String::from("Call me Ishmael. Some years ago...");
    let first_sentence = novel.split('.').next().expect("Could not find a '.'");
    let i = ImportantExcerpt {
        part: first_sentence,
    };
    // 'novel' 至少要保持有效到与 'i' 同样长的时间
    println!("{}", i.part);
}
```
这里,`'a` 确保 `ImportantExcerpt` 实例不会比 `first_sentence`(它所引用的数据)存活得更久。

#### 3. Enum 定义中的 Lifetime

与 struct 类似,如果某个 enum 的 variant 持有 reference,它也需要一个 lifetime 参数。

```rust
enum Message<'a> {
    Text(&'a str),
    Quit,
}

fn main() {
    let msg_data = String::from("Hello from enum!");
    let msg = Message::Text(msg_data.as_str());
    // 'msg_data' 至少要保持有效到与 'msg' 同样长的时间
}
```

#### 4. 方法定义中的 Lifetime

在为带有 lifetime 参数的 struct 实现方法时,你常常需要用到 lifetime 标注。

```rust
impl<'a> ImportantExcerpt<'a> {
    // 方法的 lifetime 参数通常与 struct 的 lifetime 参数相同。
    fn level(&self) -> i32 {
        3
    }

    // 如果方法返回的 reference 与 struct 的 reference 相关联,就需要标注。
    fn announce_and_return_part(&self, announcement: &str) -> &'a str {
        println!("Attention: {}", announcement);
        self.part
    }
}
```

### Lifetime 约束(`'a: 'b`)

lifetime 约束用于表达一个 lifetime 必须 "outlive"(存活得更久)或 "至少与另一个 lifetime 一样长"。其语法为 `'a: 'b`。

**示例:需要 lifetime 约束的 trait 实现**

```rust
trait MyTrait<'a> {
    fn get_ref(&self) -> &'a str;
}

struct MyStruct<'b> {
    data: &'b str,
}

impl<'a, 'b> MyTrait<'a> for MyStruct<'b>
where
    'b: 'a, // lifetime 'b 必须比 'a 存活得更久,或与之相等
{
    fn get_ref(&self) -> &'a str {
        // 这是安全的,因为 'b 保证至少与 'a 存活得一样长。
        // 因此,将一个 lifetime 为 'b 的 reference 作为 'a 返回是有效的。
        self.data
    }
}
```
这里,`'b: 'a` 确保 `MyStruct` 所引用的数据(`'b`)至少存活到 `MyTrait` 所要求的 lifetime(`'a`)那么长。

### `'static` Lifetime

`'static` 是一个特殊的 lifetime,表示数据在整个程序运行期间都有效。

*   **字符串字面量:** `let s: &'static str = "hello world";`
*   **全局静态变量:** `static MY_CONSTANT: i32 = 42;`
*   **线程安全:** 在多线程编程中,`std::thread::spawn` 通常要求闭包及其捕获的变量为 `'static`。这可以防止在线程比其所引用的数据存活得更久时,reference 变为无效。

### 为何它 "不寻常" 却必要

对于来自带垃圾回收或手动内存管理语言的开发者来说,lifetime 语法可能显得不寻常且令人生畏。然而,它是 Rust 设计中不可或缺的一部分:

1.  **编译期内存安全:** lifetime 是 Rust 独特的解决方案,让它无需垃圾回收器即可获得媲美 C/C++ 的性能,同时在编译期保证内存安全。
2.  **强制 reference 有效性:** 它们迫使开发者显式地思考并界定 reference 的有效性,从而杜绝一整类与内存相关的 bug。
3.  **与编译器的契约:** lifetime 标注是你与 Rust 编译器之间的一份契约。你声明各 reference 之间的关系,编译器则验证你的承诺是否成立。

尽管起初颇具挑战,但一旦理解了 lifetime,它就会从一种看似的负担转变为编写安全、高效、健壮 Rust 代码的强大工具。编译器的 elision 规则已经处理了许多常见情况,因此只有在出现歧义时才需要显式标注。
