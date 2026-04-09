import os
import re
import time
from deep_translator import GoogleTranslator

# Pattern to find any sequence of Chinese characters
CHINESE_PATTERN = re.compile(r"[\u4e00-\u9fa5]+")

def translate_text(text):
    if not text.strip():
        return text
    try:
        # Use deep-translator to translate to English
        translated = GoogleTranslator(source='auto', target='en').translate(text)
        return translated
    except Exception as e:
        print(f"Error translating: {text} - {e}")
        # Sleep briefly and retry once
        time.sleep(1)
        try:
            return GoogleTranslator(source='auto', target='en').translate(text)
        except:
            return text

def process_file(file_path):
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        
        if not CHINESE_PATTERN.search(content):
            return

        print(f"Processing: {file_path}")
        lines = content.splitlines()
        new_lines = []
        changed = False
        
        for line in lines:
            if CHINESE_PATTERN.search(line):
                # Preserving leading whitespace for code structure
                stripped = line.lstrip()
                indent = line[:len(line) - len(stripped)]
                
                # If it is a comment, we want to translate the whole thing
                # If it is a string in code, we might want to be more careful, 
                # but translating the line usually works well for simple cases.
                translated = translate_text(stripped)
                new_lines.append(indent + translated)
                changed = True
            else:
                new_lines.append(line)
        
        if changed:
            with open(file_path, "w", encoding="utf-8") as f:
                f.write("\n".join(new_lines) + "\n")
            print(f"Successfully updated: {file_path}")
    except Exception as e:
        print(f"Failed to process {file_path}: {e}")

def main():
    target_extensions = (".swift", ".h", ".m", ".md", ".strings", ".plist", ".json", ".podspec")
    exclude_dirs = {"Pods", ".git", ".build", ".swiftpm", ".github", "xcuserdata", ".xcodeproj", ".xcworkspace"}

    for root, dirs, files in os.walk("."):
        # Prune excluded directories
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            if file.endswith(target_extensions):
                process_file(os.path.join(root, file))

if __name__ == "__main__":
    main()
