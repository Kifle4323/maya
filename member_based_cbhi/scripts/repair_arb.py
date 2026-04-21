import json
import os

def repair_arb(lang):
    base_path = r"c:\Users\hp\Desktop\Member_Based_CBHI\member_based_cbhi\lib\l10n"
    en_path = os.path.join(base_path, "app_en.arb")
    target_path = os.path.join(base_path, f"app_{lang}.arb")
    
    if not os.path.exists(target_path):
        print(f"File {target_path} not found")
        return

    with open(en_path, 'r', encoding='utf-8') as f:
        en_data = json.load(f)
    
    with open(target_path, 'r', encoding='utf-8') as f:
        target_data = json.load(f)
    
    new_target = {}
    
    # Identify all @keys in EN
    en_metadata = {k: v for k, v in en_data.items() if k.startswith('@')}
    
    # 1. Process regular keys
    for k, v in target_data.items():
        if k.startswith('@'):
            continue
        
        # Skip junk keys observed in problematic files
        if k == "placeholders": continue
        if k == "months" and isinstance(v, str) and 'type' in v: continue
        if isinstance(v, str) and '{"type"' in v: continue
            
        new_target[k] = v
        
        # If this key has placeholders, ensure metadata exists
        if '{' in str(v):
            meta_key = f"@{k}"
            # If target already has it, keep it. If not, take from EN
            if meta_key in target_data:
                new_target[meta_key] = target_data[meta_key]
            elif meta_key in en_metadata:
                new_target[meta_key] = en_metadata[meta_key]
    
    # 2. Re-insert @@locale
    if "@@locale" in target_data:
        new_target["@@locale"] = target_data["@@locale"]
    elif "@@locale" not in new_target:
        new_target["@@locale"] = lang

    # Sort keys for consistency but keep @@locale at top if possible
    final_output = {}
    if "@@locale" in new_target:
        final_output["@@locale"] = new_target.pop("@@locale")
    
    for k in sorted(new_target.keys()):
        final_output[k] = new_target[k]
            
    with open(target_path, 'w', encoding='utf-8') as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)
    
    print(f"Successfully repaired {target_path}")

if __name__ == "__main__":
    repair_arb('om')
    repair_arb('am')
