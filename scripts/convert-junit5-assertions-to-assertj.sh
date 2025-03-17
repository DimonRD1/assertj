#!/bin/bash

# Script to convert JUnit 5 assertions to AssertJ assertions
# Based on: https://assertj.github.io/doc/#assertj-migration
# Note: Cannot handle all cases (e.g., multiline assertions)

set -e  # Exit on any error

# Default file pattern
DEFAULT_PATTERN="*Test.java"

# Print usage information
usage() {
    cat << EOF
NAME
    $(basename "$0") - Converts JUnit 5 assertions to AssertJ assertions

SYNOPSIS
    $(basename "$0") [Pattern] [-h|--help]

OPTIONS
    -h, --help       Display this help message
    [Pattern]        Find pattern for test files (default: "$DEFAULT_PATTERN")
                     Use quotes to prevent shell expansion (e.g., "*.java")

DESCRIPTION
    Converts common JUnit 5 assertions to AssertJ equivalents.
    Note: Multiline assertions may not convert correctly.
    After running, optimize imports in your IDE and add:
    "import static org.assertj.core.api.Assertions.within;" if using delta assertions.

EXAMPLE
    $(basename "$0") "*.IT.java"

AUTHOR
    Adapted from JUnit 4 script at https://assertj.github.io/doc/#assertj-migration
    Modified for JUnit 5 argument order (message as last parameter).
EOF
    exit 0
}

# Handle SED differences between platforms
setup_sed() {
    SED_OPTIONS=(-i -e)
    case "$(uname)" in
        Darwin*) SED_OPTIONS=(-i "" -e) ;;  # BSD sed (macOS)
        *) SED_OPTIONS=(-i -e) ;;           # GNU sed (Linux)
    esac
}

# Replace pattern in all matching files
replace_in_files() {
    local pattern="$1"
    local desc="$2"
    echo " - $desc"
    for file in $MATCHED_FILES; do
        sed -E "${SED_OPTIONS[@]}" "$pattern" "$file" || {
            echo "Warning: Failed to process $file" >&2
            continue
        }
    done
}

# Main conversion function
convert_assertions() {
    echo ""
    echo "Converting JUnit 5 assertions to AssertJ in files matching: $FILES_PATTERN"
    echo ""

    # Common regex components
    local any_value='([^",]*|".*[^\]"|.*\(.*\))'
    local message='(".*[^\]")'

    echo "Converting assertions:"
    # 1. assertEquals(0, size) -> isEmpty()
    replace_in_files "s/assertEquals\([[:blank:]]*0,[[:blank:]]*$any_value\.size\(\),[[:blank:]]*$message\)/assertThat(\1).as(\2).isEmpty()/g" \
        "assertEquals(0, myList.size()) -> assertThat(myList).isEmpty()"
    replace_in_files "s/assertEquals\([[:blank:]]*0,[[:blank:]]*$any_value\.size\(\)\)/assertThat(\1).isEmpty()/g" \
        "assertEquals(0, myList.size()) -> assertThat(myList).isEmpty() (no message)"

    # 2. assertEquals(size, list.size()) -> hasSize()
    replace_in_files "s/assertEquals\([[:blank:]]*([[:digit:]]*),[[:blank:]]*$any_value\.size\(\),[[:blank:]]*$message\)/assertThat(\2).as(\3).hasSize(\1)/g" \
        "assertEquals(expectedSize, myList.size()) -> assertThat(myList).hasSize(expectedSize)"
    replace_in_files "s/assertEquals\([[:blank:]]*([[:digit:]]*),[[:blank:]]*$any_value\.size\(\)\)/assertThat(\2).hasSize(\1)/g" \
        "assertEquals(expectedSize, myList.size()) -> assertThat(myList).hasSize(expectedSize) (no message)"

    # 3. assertEquals(double, actual, delta) -> isCloseTo()
    replace_in_files "s/assertEquals\($any_value,[[:blank:]]*$any_value,[[:blank:]]*$any_value,[[:blank:]]*$message\)/assertThat(\2).as(\4).isCloseTo(\1, within(\3))/g" \
        "assertEquals(expectedDouble, actual, delta) -> assertThat(actual).isCloseTo(expectedDouble, within(delta))"
    replace_in_files "s/assertEquals\([[:blank:]]*$any_value,[[:blank:]]*$any_value,[[:blank:]]*$any_value\)/assertThat(\2).isCloseTo(\1, within(\3))/g" \
        "assertEquals(expectedDouble, actual, delta) -> assertThat(actual).isCloseTo(expectedDouble, within(delta)) (no message)"

    # ... (similar improvements for other replacements)

    # Post-conversion instructions
    cat << EOF

Post-conversion steps:
1. Optimize imports in your IDE to remove unused JUnit imports
2. Add "import static org.assertj.core.api.Assertions.within;" if using delta assertions
3. Review changes - multiline assertions may need manual conversion
EOF
}

# Main execution
main() {
    # Handle help flags
    [ "$1" = "-h" ] || [ "$1" = "--help" ] && usage

    # Set file pattern
    FILES_PATTERN="${1:-$DEFAULT_PATTERN}"
    MATCHED_FILES=$(find . -name "$FILES_PATTERN" 2>/dev/null) || {
        echo "Error: No files found matching pattern '$FILES_PATTERN'" >&2
        exit 1
    }
    [ -z "$MATCHED_FILES" ] && {
        echo "Warning: No matching files found for pattern '$FILES_PATTERN'" >&2
        exit 0
    }

    setup_sed
    convert_assertions
}

main "$@"
