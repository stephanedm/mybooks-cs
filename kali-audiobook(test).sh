import fitz  # PyMuPDF
import time
import os

PDF_PATH = "your_file.pdf"

def clear_screen():
    os.system("cls" if os.name == "nt" else "clear")

def wait_for_action(timeout=3):
    print(f"\nWaiting {timeout} seconds... (Press ENTER to stop auto-next)")
    start = time.time()
    while time.time() - start < timeout:
        if os.name == "nt":
            import msvcrt
            if msvcrt.kbhit():
                key = msvcrt.getch()
                if key == b'\r':  # ENTER key
                    return True
        else:
            import select, sys
            if select.select([sys.stdin], [], [], 0)[0]:
                if sys.stdin.readline().strip() == "":
                    return True
        time.sleep(0.1)
    return False  # Auto-next

def main():
    doc = fitz.open(PDF_PATH)
    total_pages = len(doc)

    page_index = 0

    while page_index < total_pages:
        clear_screen()
        page = doc[page_index]
        text = page.get_text()

        print(f"=== PAGE {page_index + 1}/{total_pages} ===\n")
        print(text[:1500])  # Print first part (avoid terminal overflow)
        print("\n(Manual mode: options below)")
        print("[ENTER] = Do nothing (auto-next in 3s)")
        print("[n]     = Go to next page immediately")
        print("[p]     = Go to previous page")
        print("[q]     = Quit")

        # Wait for user action or auto-next
        print("")
        action_triggered = wait_for_action(timeout=3)

        if action_triggered:
            # user pressed ENTER -> STOP auto-next, ask for command
            cmd = input("\nCommand: ").strip().lower()
        else:
            # Auto-next triggered
            cmd = "n"

        if cmd == "n" or cmd == "":
            page_index += 1
        elif cmd == "p":
            page_index = max(0, page_index - 1)
        elif cmd == "q":
            break
        else:
            print("Unknown command. Moving on...")
            time.sleep(1)
            page_index += 1

    clear_screen()
    print("Finished reading the PDF. Goodbye!")

if __name__ == "__main__":
    main()
