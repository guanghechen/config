---
title: Transformer Workflow
tags: [ai, llm, transformer]
updated: 2026-09-03
---

# Transformer Workflow

Transformer 的核心是：把 token 序列变成向量序列，让每个位置通过
**Attention** 读取相关上下文，再通过 **FFN** 独立变换每个位置的表示。
多个 block 堆叠后，模型把最终表示映射为任务输出或下一个 token 的概率。

本文先讲所有 Transformer 共享的计算，再分别说明原始 encoder–decoder、
encoder-only 和现代 decoder-only LLM 的完整 workflow。

## 1. 先看全局数据流

```text
text
  │
  ▼
tokenizer ──▶ token IDs
  │
  ▼
token embedding + position information
  │
  ▼
N × Transformer block
  │
  ▼
contextual hidden states
  │
  ├──▶ task head                  (classification, embedding, ...)
  └──▶ LM head ──▶ logits ──▶ next-token probabilities
```

需要始终区分两层概念：

- **架构内的一次 forward pass**：整段已知 token 可以并行计算。
- **自回归生成循环**：每次 forward pass 只决定下一个 token，然后把它追加到上下文中。

假设：

- `B`：batch size
- `T`：sequence length
- `D`：hidden size，即 `d_model`
- `H`：attention head 数量
- `d_k = D / H`：每个 head 的维度
- `V`：vocabulary size

主干中的 hidden states 通常具有 shape `[B, T, D]`。

## 2. Text → Token IDs

模型不会直接读取字符串。Tokenizer 先把文本切成 token，再把每个 token 映射为
vocabulary 中的整数 ID。

```text
"Transformers are useful."
        │ tokenizer
        ▼
["Transform", "ers", " are", " useful", "."]
        │ vocabulary lookup
        ▼
[1842, 391, 527, 9214, 13]
```

示例仅表达过程；实际切分和 ID 由具体 tokenizer 决定。Token 往往是 subword，
不等于自然语言中的“单词”。通常还会使用特殊 token：

- `<BOS>`：序列开始。
- `<EOS>`：序列结束。
- `<PAD>`：把 batch 中不同长度的序列补齐。

输出是 `input_ids: [B, T]`。同时可能生成 `attention_mask`，用于标记哪些位置是
真实 token、哪些是 padding。

## 3. Token IDs → 初始向量

### 3.1 Token embedding

Embedding matrix `E ∈ R^(V×D)` 相当于一个可训练的 lookup table：

```text
X_token = E[input_ids]              # [B, T, D]
```

同一个 token ID 初始会查到同一个向量；经过 Transformer 后，它在不同上下文中的
hidden state 才会不同。

### 3.2 Position information

纯 Attention 不知道 token 的先后顺序，因此必须注入位置信息。常见做法包括：

- 原始 Transformer：把 sinusoidal positional encoding 加到 embedding 上。
- 一些模型：使用 learned positional embedding。
- 许多现代 LLM：对 Attention 的 `Q`、`K` 应用 RoPE，而不是直接给输入加位置向量。

使用 absolute positional encoding 时，可以写成：

```text
X = token embedding + position embedding      # [B, T, D]
```

RoPE 等机制不做这次 addition，而是在每个 Attention 层中把位置信息作用到 `Q`、
`K`。无论具体实现如何，目标都是让后续 Attention 能区分 token identity 与顺序。
然后根据实现应用 dropout，进入第一个 Transformer block。

## 4. Attention：让一个位置读取其他位置

### 4.1 生成 Query、Key、Value

输入 `X` 分别经过三个 learned linear projection：

```text
Q = X · W_Q
K = X · W_K
V = X · W_V
```

可以用检索来理解三者的角色：

- `Q`（Query）：当前位置想找什么信息。
- `K`（Key）：每个位置提供什么匹配线索。
- `V`（Value）：匹配后实际取回什么内容。

`Q`、`K` 决定“关注谁”，`V` 决定“读到什么”。它们都是从 hidden states
学习得到的表示，不是人工指定的语义字段。

### 4.2 Scaled dot-product attention

把各 head 放进同一 batch 并行计算时，核心公式为：

```text
scores  = Q · Kᵀ / sqrt(d_k) + mask       # [B, H, T_q, T_k]
weights = softmax(scores, dim=-1)
output  = weights · V                     # [B, H, T_q, d_k]
```

逐步看：

1. `Q · Kᵀ` 计算每个 query 与各 key 的相关性。
2. 除以 `sqrt(d_k)`，避免维度较大时 dot product 过大、softmax 梯度过小。
3. 加入 mask，禁止读取不应可见的位置。
4. softmax 把每行 score 变成和为 `1` 的权重。
5. 对 `V` 做加权求和，得到融合上下文的新表示。

### 4.3 Mask 决定“允许看哪里”

常见的 mask 有两类：

- **Padding mask**：不读取 `<PAD>`。
- **Causal mask**：位置 `t` 只能读取 `≤ t` 的位置，不能偷看未来 token。

Causal mask 的可见性如下，`✓` 表示 query 可以读取对应 key：

```text
             key position
query          1   2   3   4
position 1     ✓   ·   ·   ·
         2     ✓   ✓   ·   ·
         3     ✓   ✓   ✓   ·
         4     ✓   ✓   ✓   ✓
```

实现中，被 mask 的 score 通常在 softmax 前设为极小值，使其权重接近 `0`。

### 4.4 Multi-head attention

模型不会只做一次 Attention。它把 `D` 维空间分成 `H` 个 head，每个 head 使用
独立 projection，在不同表示子空间中计算 Attention：

```text
head_i = Attention(Q_i, K_i, V_i)
MHA(X) = Concat(head_1, ..., head_H) · W_O
```

各 head 的输出 concat 后回到 `[B, T, D]`，再通过 `W_O` 混合。不同 head
可以学习不同关系，但并不保证每个 head 都有稳定、可命名的人类语义。

## 5. 一个 Transformer block 做什么

一个 block 主要包含两个子层：

1. **Multi-head Attention**：跨 token 交换信息。
2. **Feed-Forward Network（FFN/MLP）**：对每个 token 位置独立做非线性变换。

FFN 对所有位置使用相同参数，但各位置独立计算：

```text
FFN(x) = W_2 · activation(W_1 · x + b_1) + b_2
```

中间维度通常大于 `D`。Activation 常见 ReLU、GELU、SiLU/SwiGLU，具体取决于
模型。

Attention 和 FFN 周围还有：

- **Residual connection**：保留原输入并改善深层网络的梯度传播。
- **LayerNorm**：稳定各层 hidden states 的数值分布。
- **Dropout**：training 时使用的正则化；inference 时关闭。

现代 LLM 常见的 Pre-LN workflow 是：

```text
X ──▶ LayerNorm ──▶ Attention ──▶ + X ──▶ X'
X' ─▶ LayerNorm ──▶ FFN       ──▶ + X' ─▶ output
```

原始 2017 Transformer 使用 Post-LN，即先做 residual addition，再做 LayerNorm。
二者不能在不匹配 checkpoint 的情况下随意互换。

### 5.1 LayerNorm 中的 mean 和 variance

对某个 token 的 `D` 维 hidden state，LayerNorm 计算：

```text
mean     = D 个分量的平均值
variance = D 个分量相对 mean 的平方偏差的平均值
normalized = (x - mean) / sqrt(variance + epsilon)
output     = gamma * normalized + beta
```

也就是说，LayerNorm 通常沿每个 token 的 hidden dimension 做归一化，不跨 token，
也不依赖 batch 中的其他样本。许多现代 LLM 使用 RMSNorm；它不减 mean，只按
root mean square 缩放。

## 6. 三类 Transformer 如何组装 block

### 6.1 Encoder-only

典型用途：文本分类、token classification、embedding、masked language modeling。

```text
input tokens
    │
    ▼
bidirectional self-attention + FFN
    │                       × N
    ▼
contextual representation for every input position
    │
    ▼
task-specific head
```

这里的 self-attention 通常没有 causal mask，所以每个非 padding 位置都能看到左右
两侧上下文。BERT 属于这一类。

### 6.2 Decoder-only

典型用途：GPT 类自回归 LLM。

```text
prompt / previous tokens
    │
    ▼
causal self-attention + FFN
    │                  × N
    ▼
LM head
    │
    ▼
next-token logits
```

每层只有 causal self-attention 和 FFN，没有独立 encoder，也没有 cross-attention。
模型在每个位置预测紧随其后的 token。

### 6.3 Encoder–decoder

这是原始 Transformer，用于机器翻译等 sequence-to-sequence 任务。

```text
source tokens                                target tokens shifted right
     │                                                  │
     ▼                                                  ▼
encoder: bidirectional                           decoder: causal
self-attention + FFN                             self-attention
     │                                                  │
     │ encoder memory                                   ▼
     └────────────────────────────────────────▶ cross-attention
                                                        │
                                                        ▼
                                                       FFN
                                                        │  × N
                                                        ▼
                                                     LM head
```

Decoder block 比 decoder-only 多一个 **cross-attention** 子层：

- `Q` 来自 decoder 当前 hidden states。
- `K`、`V` 来自 encoder 最后一层输出，即 encoder memory。
- 含义是 decoder 在生成目标 token 时读取 source sequence。

“Decoder” 这个名称容易误导：GPT 使用 Transformer decoder 风格的 causal block，
但省略了原始 decoder 中读取 encoder 的 cross-attention。

## 7. Hidden states → 输出概率

生成模型把最后一层 hidden states 通过 LM head 投影到 vocabulary：

```text
hidden states [B, T, D]
      │ linear projection
      ▼
logits        [B, T, V]
      │ softmax over V
      ▼
probabilities [B, T, V]
```

Logit 是未归一化分数。Softmax 后才得到 vocabulary 上总和为 `1` 的概率分布。
很多模型让 LM head 与输入 token embedding 共享权重，称为 weight tying。

分类模型则可能读取特定 token 或 pooled representation，再通过 classification head
输出类别 logits。

## 8. Training workflow

### 8.1 构造输入与 label

自回归 language modeling 使用 next-token prediction。假设完整序列为：

```text
<BOS>  I  like  cats  <EOS>
```

逻辑上的输入与 label 错开一位：

```text
input:  <BOS>  I     like  cats
label:  I      like  cats  <EOS>
```

实际实现通常把同一 token tensor 分别 shift 后计算 loss。Causal mask 保证位置 `t`
预测 label 时看不到未来答案。

Encoder–decoder training 中：

- Encoder 一次读取完整 source sequence。
- Decoder 读取右移后的真实 target sequence。
- 每个 decoder 位置预测下一个 target token。

把真实历史 target token 提供给 decoder 通常称为 **teacher forcing**。

### 8.2 一次训练 step

```text
batch
  │
  ▼
tokenize + pad + masks
  │
  ▼
forward pass for all sequence positions in parallel
  │
  ▼
logits vs. labels ──▶ cross-entropy loss
  │
  ▼
backpropagation ──▶ gradients
  │
  ▼
optimizer updates parameters
```

Cross-entropy 提高正确 next token 的概率、降低其他 token 的相对概率。Loss 通常只在
有效 label 上求平均；padding 或不参与训练的 prompt token 可用 ignore mask 排除。

训练能并行预测所有位置，是因为所有正确历史 token 已知；causal mask 只限制信息可见性，
不会迫使 GPU 按 token 顺序执行整段 forward pass。

## 9. Inference workflow

Training 已知目标序列，inference 不知道，因此自回归生成必须循环：

```text
prompt
  │
  ▼
forward pass ──▶ last-position logits
  │
  ▼
select one token
  │
  ▼
append token to context
  │
  └────────────── repeat until <EOS> or a stopping condition
```

以 decoder-only LLM 为例，完整过程是：

1. Tokenize prompt。
2. 对 prompt 做 **prefill**，建立各层的上下文表示。
3. 取最后一个有效位置的 logits。
4. 用 greedy、beam search 或 temperature/top-k/top-p sampling 选择一个 token。
5. 把 token 追加到序列，执行下一次 decode step。
6. 遇到 `<EOS>`、长度上限或其他 stopping condition 时结束。
7. Tokenizer 把生成的 IDs decode 回文本。

Encoder–decoder 模型会先把 source encode 一次，再在每个 decoder step 重用 encoder
memory。Decoder-only LLM 则把 prompt 和已生成 token 放在同一 causal context 中。

### 9.1 KV cache

朴素实现每生成一个 token 都会重新计算整个历史。KV cache 保存每层过去 token 的
`K`、`V`：

```text
prefill:  compute K,V for the whole prompt and cache them
decode:   compute Q,K,V only for the new token
          append new K,V to cache
          let new Q attend to cached K,V
```

它避免重复计算历史 token 的 `K`、`V` 和早期 block 输出，显著降低 decode latency；
代价是 cache 随 context length 增长并占用显存。新 token 仍需读取允许范围内的历史。

## 10. Decoder-only LLM 端到端示例

以 prompt `"The capital of France is"` 为例：

1. Tokenizer 产生 token IDs。
2. Embedding 和 position mechanism 产生初始 hidden states。
3. 第 1 层 causal self-attention 让每个位置汇总其左侧上下文，FFN 再变换表示。
4. 相同过程重复 `N` 层；越往后，最后位置的 hidden state 融合越深的上下文。
5. LM head 把最后位置映射为 `V` 个 logits。
6. Sampling strategy 选择例如 `" Paris"` 对应的 token。
7. 将该 token 追加到序列，利用 KV cache 执行下一次 decode step。
8. 持续生成，直到停止条件满足，再 decode 为字符串。

压缩成一行就是：

```text
text → tokens → embeddings → N × (causal attention → FFN)
     → logits → select next token → append → repeat
```

## 11. 常见误区

### Attention 不是“理解”的全部

Attention 负责跨位置路由和聚合信息；FFN、residual stream、normalization、训练数据与
objective 共同决定模型行为。

### Training 并非逐 token 串行 forward

自回归 training 可以借助 shifted labels 和 causal mask 并行处理所有已知位置；真正按
token 串行的是 inference generation loop。

### Self-attention 与 cross-attention 的来源不同

- Self-attention：`Q`、`K`、`V` 来自同一序列当前层的表示。
- Cross-attention：`Q` 来自 decoder，`K`、`V` 来自 encoder memory。

### Context window 不是永久记忆

模型一次 forward pass 只能使用当前 context window 中可见的 token。超出窗口的信息需要
截断、压缩或借助外部 retrieval；KV cache 只是避免重复计算，不会扩展模型本身支持的
context length。

### 标准 Attention 对序列长度是平方复杂度

`Q · Kᵀ` 会产生 `T_q × T_k` 的 score matrix。完整 self-attention 在 sequence length
上通常具有 `O(T²)` 的计算或中间表示开销，这也是长上下文优化的重要目标。

## 12. 最小心智模型

记住四句话即可还原整个 workflow：

1. Tokenizer 把文本变成 IDs，embedding 把 IDs 变成向量。
2. Attention 让每个位置按规则读取其他位置，FFN 变换每个位置。
3. 堆叠 block 后，output head 把 hidden states 变成任务 logits。
4. Training 并行学习 next-token prediction；inference 逐 token 选择、追加并重复。

## References

- Vaswani et al., [Attention Is All You Need](https://arxiv.org/abs/1706.03762)
- Jay Alammar, [The Illustrated Transformer](https://jalammar.github.io/illustrated-transformer/)
