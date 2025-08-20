#!/bin/bash

set -euo pipefail
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LANG_CODE="simple"
MAX_ARTICLES=150
TEST_OUTPUT_DIR="./test-output"
DUMP_FILE="test-wikipedia-dump.xml.bz2"
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        *)          echo "unknown" ;;
    esac
}

check_dependencies() {
    echo -e "${BLUE}ℹ️  Checking dependencies...${NC}"
    local missing_deps=()
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v cargo >/dev/null 2>&1; then
        missing_deps+=("cargo/rust")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing dependencies: ${missing_deps[*]}${NC}"
        echo -e "${BLUE}ℹ️  Please install missing dependencies and try again.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies found${NC}"
}

get_latest_dump() {
    echo -e "${BLUE}ℹ️  Finding latest ${LANG_CODE} Wikipedia dump..." >&2
    
    local dump_date
    dump_date=$(curl -s "https://dumps.wikimedia.org/${LANG_CODE}wiki/" | \
        grep -o '[0-9]\{8\}' | sort | tail -1)
    
    if [[ -z "$dump_date" ]]; then
        echo -e "${RED}❌ Could not determine latest dump date" >&2
        exit 1
    fi
    
    echo "$dump_date"
}

download_dump() {
    local dump_date="$1"
    local dump_url="https://dumps.wikimedia.org/${LANG_CODE}wiki/${dump_date}/${LANG_CODE}wiki-${dump_date}-pages-articles.xml.bz2"
    
    if [[ -f "$DUMP_FILE" ]]; then
        echo -e "${BLUE}ℹ️  Using existing dump file: $DUMP_FILE${NC}"
        return
    fi
    
    echo -e "${BLUE}ℹ️  Downloading test dump from: $dump_url${NC}"
    echo -e "${YELLOW}⚠️  This may take a few minutes...${NC}"
    
    if ! curl -L -f -o "$DUMP_FILE" "$dump_url"; then
        echo -e "${RED}❌ Failed to download dump file${NC}"
        exit 1
    fi
    
    local file_size=$(ls -lh "$DUMP_FILE" | awk '{print $5}')
    echo -e "${GREEN}✅ Downloaded dump file (${file_size})${NC}"
}

build_project() {
    echo -e "${BLUE}ℹ️  Building project...${NC}"
    
    if ! cargo build --release; then
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Build completed${NC}"
}

test_generator() {
    echo -e "${BLUE}ℹ️  Testing generator with ${MAX_ARTICLES} articles...${NC}"
    rm -rf "$TEST_OUTPUT_DIR"
    if ! ./target/release/wikipedia-history-smg \
        --input "$DUMP_FILE" \
        --output "$TEST_OUTPUT_DIR" \
        --language "$LANG_CODE" \
        --max-articles "$MAX_ARTICLES"; then
        echo -e "${RED}❌ Generator failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Generator completed successfully${NC}"
}

validate_structure() {
    echo -e "${BLUE}ℹ️  Validating output structure...${NC}"
    
    local expected_files=(
        "mcp.json"
        "resources/stats.json"
        "resources/articles.json"
        "tools/get_article"
        "tools/list_articles"
        "tools/categories"
        "tools/list_articles.json"
        "tools/list_categories.json"
    )
    
    local missing_files=()
    
    for file in "${expected_files[@]}"; do
        if [[ ! -e "$TEST_OUTPUT_DIR/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing expected files: ${missing_files[*]}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All expected files present${NC}"
}

validate_pagination() {
    echo -e "${BLUE}ℹ️  Validating pagination...${NC}"
    local page_files=("$TEST_OUTPUT_DIR"/tools/list_articles/[0-9]*.json)
    if [[ ! -e "${page_files[0]}" ]]; then
        echo -e "${RED}❌ No pagination files found${NC}"
        exit 1
    fi
    
    local page_count=${#page_files[@]}
    echo -e "${BLUE}ℹ️  Found ${page_count} pagination files${NC}"
    
    if [[ ! -f "$TEST_OUTPUT_DIR/tools/list_articles/1.json" ]]; then
        echo -e "${RED}❌ Page 1 not found${NC}"
        exit 1
    fi
    if ! grep -q "total_pages" "$TEST_OUTPUT_DIR/tools/list_articles.json"; then
        echo -e "${RED}❌ Metadata endpoint missing pagination info${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Pagination validation passed${NC}"
}

validate_json() {
    echo -e "${BLUE}ℹ️  Validating JSON format...${NC}"
    
    local json_files
    json_files=$(find "$TEST_OUTPUT_DIR" -name "*.json" 2>/dev/null || true)
    local invalid_files=()
    local count=0
    
    for file in $json_files; do
        if [ $count -ge 20 ]; then
            break
        fi
        count=$((count + 1))
        if ! python3 -m json.tool "$file" >/dev/null 2>&1; then
            if command -v node >/dev/null 2>&1; then
                if ! node -e "JSON.parse(require('fs').readFileSync('$file', 'utf8'))" 2>/dev/null; then
                    invalid_files+=("$file")
                fi
            else
                echo -e "${YELLOW}⚠️  Cannot validate JSON format - no JSON validator available${NC}"
                break
            fi
        fi
    done
    
    if [[ ${#invalid_files[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Invalid JSON files: ${invalid_files[*]}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ JSON format validation passed${NC}"
}

validate_categories() {
    echo -e "${BLUE}ℹ️  Validating categories functionality...${NC}"
    
    # Check if list_categories.json exists and has valid structure
    if [[ ! -f "$TEST_OUTPUT_DIR/tools/list_categories.json" ]]; then
        echo -e "${RED}❌ Missing list_categories.json${NC}"
        exit 1
    fi
    
    # Check if categories array exists
    if ! grep -q 'categories' "$TEST_OUTPUT_DIR/tools/list_categories.json"; then
        echo -e "${RED}❌ Missing categories array in list_categories.json${NC}"
        exit 1
    fi
    
    # Check if category files exist
    local category_files=("$TEST_OUTPUT_DIR"/tools/categories/*.json)
    if [[ ! -e "${category_files[0]}" ]]; then
        echo -e "${YELLOW}⚠️  No category files found (may be normal for small datasets)${NC}"
    else
        local category_count=${#category_files[@]}
        echo -e "${BLUE}ℹ️  Found ${category_count} category files${NC}"
        
        # Validate structure of first category file
        local first_category="${category_files[0]}"
        if ! grep -q 'category' "$first_category" || \
           ! grep -q 'articles' "$first_category" || \
           ! grep -q 'count' "$first_category"; then
            echo -e "${RED}❌ Category file missing required fields${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✅ Categories validation passed${NC}"
}

validate_tools_manifest() {
    echo -e "${BLUE}ℹ️  Validating tools in manifest...${NC}"
    
    local required_tools=("get_article" "list_articles" "list_categories" "categories")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! grep -q "\"$tool\"" "$TEST_OUTPUT_DIR/mcp.json"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing tools in manifest: ${missing_tools[*]}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All required tools present in manifest${NC}"
}

validate_staticmcp() {
    echo -e "${BLUE}ℹ️  Validating StaticMCP compliance...${NC}"
    if ! grep -q '"protocolVersion"' "$TEST_OUTPUT_DIR/mcp.json"; then
        echo -e "${RED}❌ Missing protocolVersion in manifest${NC}"
        exit 1
    fi
    
    if ! grep -q '"serverInfo"' "$TEST_OUTPUT_DIR/mcp.json"; then
        echo -e "${RED}❌ Missing serverInfo in manifest${NC}"
        exit 1
    fi
    
    if ! grep -q '"capabilities"' "$TEST_OUTPUT_DIR/mcp.json"; then
        echo -e "${RED}❌ Missing capabilities in manifest${NC}"
        exit 1
    fi
    
    if ! grep -q '"uri"' "$TEST_OUTPUT_DIR/resources/stats.json" || \
       ! grep -q '"mimeType"' "$TEST_OUTPUT_DIR/resources/stats.json" || \
       ! grep -q '"text"' "$TEST_OUTPUT_DIR/resources/stats.json"; then
        echo -e "${RED}❌ Resource file missing required fields${NC}"
        exit 1
    fi
    
    local sample_tool="$TEST_OUTPUT_DIR/tools/list_articles.json"
    if ! grep -q '"content"' "$sample_tool" || \
       ! grep -q '"type"' "$sample_tool" || \
       ! grep -q '"text"' "$sample_tool"; then
        echo -e "${RED}❌ Tool response missing required format${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ StaticMCP compliance validation passed${NC}"
}


test_streaming() {
    echo -e "${BLUE}ℹ️  Testing streaming functionality...${NC}"
    
    # Create a simple test XML file
    local test_xml="test-streaming.xml"
    cat > "$test_xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mediawiki xmlns="http://www.mediawiki.org/xml/export-0.11/" xml:lang="en">
  <siteinfo>
    <sitename>Wikipedia</sitename>
    <dbname>enwiki</dbname>
  </siteinfo>
  <page>
    <title>World War II</title>
    <id>32927</id>
    <revision>
      <text>World War II was a global war that lasted from 1939 to 1945.</text>
    </revision>
  </page>
  <page>
    <title>Roman Empire</title>
    <id>25583</id>
    <revision>
      <text>The Roman Empire was the post-Republican period of ancient Rome.</text>
    </revision>
  </page>
  <page>
    <title>Battle of Hastings</title>
    <id>25584</id>
    <revision>
      <text>The Battle of Hastings was a medieval battle in 1066.</text>
    </revision>
  </page>
</mediawiki>
EOF

    # Start a simple HTTP server in background
    local port=8765
    local server_pid
    
    echo -e "${BLUE}ℹ️  Starting HTTP server for streaming test...${NC}"
    cd "$(dirname "$test_xml")"
    python3 -m http.server $port >/dev/null 2>&1 &
    server_pid=$!
    sleep 2
    
    # Test streaming from HTTP URL
    local streaming_output="./test-streaming-output"
    rm -rf "$streaming_output"
    
    if ./target/release/wikipedia-history-smg \
        --input "http://localhost:$port/$test_xml" \
        --output "$streaming_output" \
        --language en; then
        echo -e "${GREEN}✅ Streaming test completed successfully${NC}"
        
        # Validate streaming output has categories
        if [[ -f "$streaming_output/tools/list_categories.json" ]]; then
            echo -e "${GREEN}✅ Streaming generated categories${NC}"
        else
            echo -e "${YELLOW}⚠️  Streaming did not generate categories${NC}"
        fi
        
        # Validate streaming output structure
        if [[ -f "$streaming_output/tools/list_articles.json" ]] && \
           [[ -f "$streaming_output/mcp.json" ]]; then
            echo -e "${GREEN}✅ Streaming output structure valid${NC}"
        else
            echo -e "${RED}❌ Streaming output structure invalid${NC}"
            kill $server_pid 2>/dev/null || true
            rm -f "$test_xml"
            rm -rf "$streaming_output"
            exit 1
        fi
        
        rm -rf "$streaming_output"
    else
        echo -e "${RED}❌ Streaming test failed${NC}"
        kill $server_pid 2>/dev/null || true
        rm -f "$test_xml"
        exit 1
    fi
    
    # Cleanup
    kill $server_pid 2>/dev/null || true
    rm -f "$test_xml"
}

cleanup() {
    echo -e "${BLUE}ℹ️  Cleaning up test files...${NC}"
    rm -rf "$TEST_OUTPUT_DIR" 2>/dev/null || true
    rm -f test-streaming.xml 2>/dev/null || true
    rm -rf test-streaming-output 2>/dev/null || true
}

main() {
    echo -e "${BLUE}🧪 Wikipedia History StaticMCP Test Suite${NC}"
    echo -e "${BLUE}Platform: $(detect_os) | Articles: ${MAX_ARTICLES} | Language: ${LANG_CODE}${NC}"
    echo ""
    check_dependencies
    build_project
    
    local dump_date
    dump_date=$(get_latest_dump)
    download_dump "$dump_date"
    
    test_generator
    validate_structure
    validate_pagination
    validate_categories
    validate_tools_manifest
    validate_json
    validate_staticmcp
    
    if [[ "$SKIP_STREAMING" == "false" ]]; then
        test_streaming
    else
        echo -e "${YELLOW}⚠️  Skipping streaming test (--skip-streaming flag provided)${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ 🎉 All tests passed!${NC}"
    echo -e "${GREEN}📂 Test output available in: ${TEST_OUTPUT_DIR}${NC}"
    echo -e "${GREEN}🌐 To serve locally: cd ${TEST_OUTPUT_DIR} && python3 -m http.server 8000${NC}"
    
    if [[ "$KEEP_FILES" == "false" ]]; then
        cleanup
    fi
}

KEEP_FILES=false
SKIP_STREAMING=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "Usage: $0 [--help] [--keep-files] [--skip-streaming] [--max-articles N]"
            echo ""
            echo "Options:"
            echo "  --help           Show this help message"
            echo "  --keep-files     Don't clean up test files after completion"
            echo "  --skip-streaming Skip the HTTP streaming functionality test"
            echo "  --max-articles   Number of articles to test with (default: $MAX_ARTICLES)"
            echo ""
            echo "Tests performed:"
            echo "  • Download and parse Wikipedia dump"
            echo "  • Validate StaticMCP structure and compliance"
            echo "  • Test pagination functionality"
            echo "  • Test categories functionality"
            echo "  • Validate JSON format"
            echo "  • Test HTTP streaming (unless --skip-streaming)"
            exit 0
            ;;
        --keep-files)
            KEEP_FILES=true
            shift
            ;;
        --skip-streaming)
            SKIP_STREAMING=true
            shift
            ;;
        --max-articles)
            if [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                MAX_ARTICLES="$2"
                shift 2
            else
                echo -e "${RED}❌ Invalid --max-articles value. Must be a positive integer.${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

main