---
title: moc gera .moc vazio quando um raw string contém "//" depois de aspas
category: build-errors
module: tests
symptoms:
  - "undefined reference to `vtable for TstX`"
  - ".moc gerado com 0 bytes"
  - "moc: note: No relevant classes found. No output generated."
tags: [qt, moc, raw-string, qtest, qt-6.10.3]
---

# O que acontece

Em Qt 6.10.3 (Fedora 43), o `moc` **mis-lexa** um raw string que contenha `//` depois de uma
aspa dupla interna — exatamente a forma de toda URL num fixture XML:

```cpp
const QByteArray xml = R"(<a url="https://ex.com/y.mp3"/>)";   // <-- envenena o arquivo inteiro
```

O resultado não é um erro de compilação: o `moc` imprime `No relevant classes found`, emite um
`.moc` de **0 byte**, e a falha só aparece no link, como
`undefined reference to vtable for TstFeedParser` — apontando para longe da causa.

# Como reconhecer em 30 segundos

```bash
find build -name "<alvo>.moc" -exec wc -c {} \;      # 0 bytes = é isto
/usr/lib64/qt6/libexec/moc <arquivo>.cpp -o /tmp/p.moc   # "No relevant classes found"
```

# A regra medida

| forma | moc |
|---|---|
| `R"(texto // solto)"` (sem aspas internas antes) | ok |
| `R"(<a url="https://x"/>)"` | **quebra** |
| `R"XML(<a url="https://x"/>)XML"` (delimitador próprio) | **quebra também** |
| `"<a url=\"https://x\"/>"` (string normal escapada) | ok |
| URL sem a barra dupla | ok |

# A correção

Fixture XML com URL vai como **string normal escapada**, com `\n` explícito por linha. Deixe um
comentário no arquivo dizendo por quê — sem ele, a próxima pessoa "melhora" o código de volta
para raw string e reintroduz a falha silenciosa.

# O que NÃO funcionou

- **Delimitador customizado** (`R"XML(...)XML"`): a intuição óbvia, e não resolve — o bug está
  no lexer, não no delimitador.
- **Culpar o multilinha**: raw string de várias linhas funciona bem. O gatilho é `//` depois de
  aspa interna, e nada mais.
- **Ler a mensagem do linker**: `undefined reference to vtable` sugere fonte faltando no
  `CMakeLists.txt` ou `Q_OBJECT` esquecido. Ambas as pistas levam para o lado errado; o único
  sinal honesto é o tamanho do `.moc`.
