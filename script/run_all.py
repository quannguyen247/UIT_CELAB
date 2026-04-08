import os
import subprocess

# Xac dinh thu muc goc cua Project (Thu muc LAB02)
# File process nay nam trong LAB02/script/ -> thu muc goc la cha cua no
WORK_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC_DIR = os.path.join(WORK_DIR, "doc")
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".webp"}


def normalize_path(path):
    """Chuan hoa duong dan ve dang dung dau / de truyen cho Tcl."""
    return path.replace("\\", "/")


def quote_tcl_arg(value):
    """Boc doi so bang {} de an toan voi duong dan co dau cach."""
    safe = normalize_path(value).replace("}", "\\}")
    return "{" + safe + "}"


def discover_images():
    """Quet toan bo anh trong thu muc doc/ theo tap extension ho tro."""
    if not os.path.isdir(DOC_DIR):
        return []

    images = []
    for name in os.listdir(DOC_DIR):
        full_path = os.path.join(DOC_DIR, name)
        _, ext = os.path.splitext(name)
        if os.path.isfile(full_path) and ext.lower() in IMAGE_EXTS:
            images.append(f"doc/{name}")

    images.sort(key=str.lower)
    return images


def resolve_to_workspace_relative(raw_path):
    """Doi tu input cua user ve duong dan tuong doi tinh tu WORK_DIR."""
    candidate = raw_path.strip().strip('"').strip("'")
    if not candidate:
        return None

    if os.path.isabs(candidate):
        abs_path = candidate
    else:
        abs_path = os.path.join(WORK_DIR, candidate.replace("/", os.sep).replace("\\", os.sep))

    if not os.path.isfile(abs_path):
        return None

    rel_path = os.path.relpath(abs_path, WORK_DIR)
    return normalize_path(rel_path)


def choose_image_interactive(title, allow_empty=False):
    """Cho user chon anh bang so thu tu hoac tu nhap duong dan."""
    images = discover_images()

    print(f"\n[{title}] Danh sach anh trong doc/:")
    if images:
        for idx, rel_path in enumerate(images, 1):
            print(f"  {idx}. {rel_path}")
    else:
        print("  (khong co anh nao trong doc/)")

    while True:
        prompt = "Nhap so thu tu hoac duong dan anh"
        if allow_empty:
            prompt += " (de trong de bo qua)"
        prompt += ": "

        user_input = input(prompt).strip()

        if not user_input:
            if allow_empty:
                return None
            print("Ban chua nhap du lieu. Vui long thu lai.")
            continue

        if user_input.isdigit():
            selected_index = int(user_input) - 1
            if 0 <= selected_index < len(images):
                return images[selected_index]
            print("So thu tu khong hop le. Vui long thu lai.")
            continue

        resolved = resolve_to_workspace_relative(user_input)
        if resolved is not None:
            return resolved

        print("Duong dan khong ton tai hoac khong phai file anh. Vui long thu lai.")


def ask_brightness():
    """Nhap do sang cho LAB 2 trong mien hop le [-128, 127]."""
    while True:
        value = input("Nhap do sang ([-128,127], Enter = 0): ").strip()
        if value == "":
            return 0

        try:
            brightness = int(value)
        except ValueError:
            print("Gia tri khong phai so nguyen. Vui long thu lai.")
            continue

        if -128 <= brightness <= 127:
            return brightness

        print("Gia tri nam ngoai mien cho phep. Vui long nhap lai.")

def run_command(cmd):
    """Chuyen doi lenh sang cmd va thuc thi trong moi truong Windows"""
    print(f"\n[He thong dang chay]: {cmd}")
    # Chay lenh vsim kem cac tham so, in log truc tiep ra man hinh
    process = subprocess.Popen(cmd, shell=True, cwd=WORK_DIR)
    process.communicate() # Cho toi khi lenh chay xong
    
    if process.returncode != 0:
        print(f"\n[!!! CANH BAO !!!] Lenh thuc thi bi loi hoac dung dot ngot (Ma loi: {process.returncode})")
        return False

    return True

def run_lab1():
    print("\n" + "="*60)
    print(" DANH GIA LAB 1: LOC TRUNG VI (MEDIAN FILTER) - TAY NHIEU")
    print("="*60)
    input_img = choose_image_interactive("LAB1 - Anh dau vao")
    ref_img = choose_image_interactive("LAB1 - Anh tham chieu PSNR/SSIM", allow_empty=True)
    if ref_img is None:
        ref_img = input_img

    output_img = "temp/test1_output.jpg"

    print(f"[LAB1] Anh dau vao: {input_img}")
    print(f"[LAB1] Anh tham chieu so sanh: {ref_img}")
    
    # Goi kich ban Tcl de chay toan bo flow
    cmd = (
        f'vsim -c -do "do script/flow1.tcl '
        f'{quote_tcl_arg(input_img)} {quote_tcl_arg(output_img)} {quote_tcl_arg(ref_img)}"'
    )
    return run_command(cmd)

def run_lab2():
    print("\n" + "="*60)
    print(" DANH GIA LAB 2: CHUYEN DOI ANH RGB SANG GRAYSCALE")
    print("="*60)
    input_img = choose_image_interactive("LAB2 - Anh dau vao")
    output_img = "temp/test2_output.jpg"
    
    # Cung cap lua chon tuy chinh do sang truc tiep tren man hinh
    print("\nBan co the thay doi do sang (Brightness) cho khoi RGB2GRAY phan cung.")
    print("Gioi han cho phep tu -128 (Toi het co) den 127 (Sang het co).")
    brightness = ask_brightness()
        
    cmd = (
        f'vsim -c -do "do script/flow2.tcl '
        f'{quote_tcl_arg(input_img)} {quote_tcl_arg(output_img)} {brightness}"'
    )
    return run_command(cmd)

def main():
    # Doi thu muc lam viec hien tai (cwd) ve thu muc goc de tim thay /sim, /rtl
    os.chdir(WORK_DIR)
    
    while True:
        # Xoa trang man hinh command cho sach se truoc khi hien thi Menu
        os.system('cls' if os.name == 'nt' else 'clear')
        
        print("=======================================================================")
        print("          HE THONG DEMO VA DANH GIA - THIET KE HDL LAB 2")
        print("          SV Thuc Hien: Nguyen Dong Quan, Huynh Nhat Phat")
        print("=======================================================================")
        print(" 1. Demo LAB 1: Bo loc Trung Vi (Median Filter) - Kiem tra tren anh nhieu")
        print(" 2. Demo LAB 2: Bo chuyen mau RGB sang Gray - Tuy chinh do sang")
        print(" 3. Chay Lien Tuc 2 LAB")
        print(" 0. Thoat Chuong Trinh")
        print("=======================================================================")
        
        choice = input("Moi nhap lua chon (0-3): ").strip()
        
        if choice == '1':
            run_lab1()
            input("\nHoan tat Demo LAB 1. Nhan Enter de quay lai Menu...")
        elif choice == '2':
            run_lab2()
            input("\nHoan tat Demo LAB 2. Nhan Enter de quay lai Menu...")
        elif choice == '3':
            ok_lab1 = run_lab1()
            if ok_lab1:
                ok_lab2 = run_lab2()
                if ok_lab2:
                    input("\nDa chay thanh cong CA 2 LAB. Nhan Enter de quay lai Menu...")
                else:
                    input("\nLAB 2 gap loi. Nhan Enter de quay lai Menu...")
            else:
                print("\nDung chuoi chay vi LAB 1 gap loi.")
                input("\nNhan Enter de quay lai Menu...")
        elif choice == '0':
            break
        else:
            print("\nLua chon khong hop le, ban chua go dung so yeu cau!")
            input("Nhan Enter de tiep tuc...")

if __name__ == "__main__":
    main()
