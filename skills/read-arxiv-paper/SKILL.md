---
name: read-arxiv-paper
description: Given an arxiv URL, download the TeX source, read the paper, and produce a summary markdown file
license: MIT
source: https://github.com/karpathy/nanochat
---

# Read Arxiv Paper

## Overview

Given an arxiv URL, this skill downloads the TeX source (not the PDF), reads through the paper, and produces a structured summary saved to disk.

## Instructions

### Part 1: Normalize the URL

Given an arxiv URL like `https://www.arxiv.org/abs/2601.07372`, construct the TeX source URL:

```
https://www.arxiv.org/src/2601.07372
```

Notice the `/src/` in the URL.

### Part 2: Download the paper source

Fetch the URL to a local `.tar.gz` file. Store it at `~/.cache/nanochat/knowledge/{arxiv_id}.tar.gz`.

If the file already exists, do not re-download it.

### Part 3: Unpack the file

Unpack the contents into `~/.cache/nanochat/knowledge/{arxiv_id}/` directory.

### Part 4: Locate the entrypoint

Every LaTeX source usually has an entrypoint (e.g. `main.tex`). Find and identify it.

### Part 5: Read the paper

Read the entrypoint file, then recurse through all other relevant source files (included `.tex` files, `.bib`, figures, etc.) to comprehensively read the paper.

### Part 6: Report

Once you have read the paper, produce a summary as a markdown file at `./knowledge/summary_{tag}.md`. Use a reasonable `tag` (e.g. `conditional_memory`) that reflects the paper's topic. Make sure the tag doesn't overwrite an existing file.

In the summary, connect the paper's ideas to the `nanochat` project context — read relevant parts of the nanochat codebase and explicitly draw connections between the paper's contributions and how they might apply to nanochat.

## Source

This skill is adapted from [karpathy/nanochat](https://github.com/karpathy/nanochat/blob/master/.claude/skills/read-arxiv-paper/SKILL.md).
