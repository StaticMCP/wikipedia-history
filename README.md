# Wikipedia History StaticMCP

A history-focused Wikipedia StaticMCP deployment providing access to historical articles through the Model Context Protocol.

🌐 **Live Deployment**: https://staticmcp.github.io/wikipedia-history

## What's Included

This StaticMCP focuses on historical content from Wikipedia, organized into comprehensive categories:

- **Wars & Military**: World wars, battles, sieges, campaigns, conflicts, military history
- **Empires & Kingdoms**: Ancient civilizations, dynasties, monarchies, emperors, kings, queens  
- **Ancient History**: Ancient civilizations, BC periods, Egypt, Rome, Greece
- **Medieval History**: Middle Ages, Crusades, feudal systems, knights
- **Political History**: Presidents, democracies, republics, revolutions, independence movements, treaties
- **Cultural Heritage**: Culture, heritage sites, monuments, archaeology, museums

## Features

- **🔍 Smart Search**: Find articles by keywords with intelligent content matching
- **📖 Full Articles**: Access complete Wikipedia article content
- **📑 Pagination**: Browse large collections efficiently with page-by-page navigation
- **🏷️ Categories**: Discover articles organized by historical themes
- **🌊 Streaming Support**: Process massive Wikipedia dumps without disk space constraints
- **⚡ GitHub Actions**: Automated monthly updates from latest Wikipedia dumps

## Quick Start

Add to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "wikipedia-history": {
      "command": "npx",
      "args": [
        "staticmcp-bridge",
        "https://staticmcp.github.io/wikipedia-history/"
      ]
    }
  }
}
```

Then ask Claude questions like:
- "Tell me about the Roman Empire"
- "What were the causes of World War II?"
- "Search for articles about ancient civilizations"
- "Show me articles in the wars category"

## Available Tools

### `get_article`
Retrieve the complete content of a specific historical article.

**Example:**
```json
{
  "name": "get_article", 
  "parameters": {
    "title": "World War II"
  }
}
```

### `list_articles`
Browse articles with pagination support.

**Example:**
```json
{
  "name": "list_articles",
  "parameters": {
    "page": 1
  }
}
```

### `list_categories`
Get all available article categories.

**Example:**
```json
{
  "name": "list_categories",
  "parameters": {}
}
```

### `categories`
Get articles from a specific category.

**Example:**
```json
{
  "name": "categories",
  "parameters": {
    "category": "wars"
  }
}
```

## Local Development

### Prerequisites
- Rust 1.70+
- Wikipedia XML dump file (or HTTP URL for streaming)

### Setup

```bash
# Clone with submodules
git clone --recursive https://github.com/staticmcp/wikipedia-history
cd wikipedia-history

# Build
cargo build --release

# Option 1: Generate from local file
./target/release/wikipedia-history-smg \
  --input enwiki-latest-pages-articles.xml.bz2 \
  --output ./output \
  --language en \
  --max-articles 1000

# Option 2: Stream from URL (saves disk space)
./target/release/wikipedia-history-smg \
  --input https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-pages-articles.xml.bz2 \
  --output ./output \
  --language simple \
  --max-articles 1000
```

### Testing

Run the comprehensive test suite:

```bash
# Run all tests including streaming and categories
./test.sh

# Run tests with limited articles (faster)
./test.sh --max-articles 100

# Skip streaming tests (for CI environments)
./test.sh --max-articles 100 --skip-streaming

# Get help
./test.sh --help
```

The test suite validates:
- ✅ File structure and StaticMCP compliance
- ✅ JSON format validation
- ✅ Pagination functionality
- ✅ Categories and categorization logic
- ✅ Tools manifest completeness
- ✅ HTTP streaming capabilities

### Development Commands

```bash
# Run unit tests
cargo test

# Run clippy for code quality
cargo clippy

# Format code
cargo fmt

# Build for release
cargo build --release
```

## Automated Deployment

This repository automatically:
- 🔄 Checks for new Wikipedia dumps monthly via GitHub Actions
- 📥 Downloads the latest English Wikipedia dump using HTTP streaming  
- 🏛️ Filters for history-related articles using advanced topic matching
- 📦 Generates optimized StaticMCP files with categories and pagination
- 🚀 Deploys to GitHub Pages at https://staticmcp.github.io/wikipedia-history

### Manual Trigger

You can manually trigger a rebuild:
1. Go to [Actions](https://github.com/staticmcp/wikipedia-history/actions)
2. Select "Generate Wikipedia History StaticMCP"
3. Click "Run workflow"
4. Choose language and options

## Output Structure

Generated StaticMCP contains:

```
output/
  ├── mcp.json                    # StaticMCP manifest with all tools
  ├── resources/
  │     ├── stats.json             # Collection statistics & metadata
  │     └── articles.json          # Complete article index
  └── tools/
        ├── list_articles.json     # Pagination index and metadata
        ├── list_articles/
        │     ├── 1.json             # First page of articles (50 articles)
        │     ├── 2.json             # Second page of articles 
        │     ├── 3.json             # Third page of articles
        │     └── ...
        ├── list_categories.json   # Available categories list
        ├── categories/
        │     ├── wars.json          # Articles in wars category
        │     ├── empires.json       # Articles in empires category
        │     ├── ancient.json       # Articles in ancient category
        │     ├── medieval.json      # Articles in medieval category
        │     ├── politics.json      # Articles in politics category
        │     ├── culture.json       # Articles in culture category
        │     └── ...
        └── get_article/
              ├── world_war_ii.json  # Complete article content
              ├── roman_empire.json
              ├── ancient_egypt.json
              └── ...
```

## Core Technology

Built with [`wikipedia_core`](https://github.com/staticmcp/wikipedia_core) crate providing:
- **Streaming XML Parser**: Process 22GB+ Wikipedia dumps without storing locally
- **Advanced Topic Filtering**: Smart classification of history-related content
- **Incremental Categorization**: Real-time article categorization during processing
- **StaticMCP Generation**: Full compliance with StaticMCP specification
- **Collision Handling**: UTF-8 filename encoding with hash-based deduplication
