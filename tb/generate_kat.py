import binascii
import sys
sys.path.insert(0, '.')
from pyascon_official import ascon_encrypt

def bytes_to_hex(b):
    return binascii.hexlify(b).decode('ascii').upper()

def generate_kat_file(filename="LWC_AEAD_KAT_128_128.txt", max_len=32):
    # Standard NIST KAT fixed Key and Nonce (same as original script)
    key = bytes.fromhex("000102030405060708090A0B0C0D0E0F")
    nonce = bytes.fromhex("101112131415161718191A1B1C1D1E1F")

    with open(filename, "w") as f:
        f.write("# NIST Lightweight Cryptography (LWC) KAT Vectors\n")
        f.write("# Algorithm: Ascon-AEAD128 (NIST SP 800-232)\n")
        f.write("# Generated automatically via Python reference model\n\n")

        count = 1
        # Nested loops: 33 AD lengths x 33 PT lengths = 1089 total vectors
        for ad_len in range(max_len + 1):
            for pt_len in range(max_len + 1):
                # Generate deterministic pattern: 00, 01, 02...
                pt = bytes(i % 256 for i in range(pt_len))
                ad = bytes((i + 48) % 256 for i in range(ad_len))

                # Ascon-AEAD128 encryption (returns ciphertext + 16-byte tag)
                ct_and_tag = ascon_encrypt(key, nonce, ad, pt, variant="Ascon-AEAD128")

                f.write(f"Count = {count}\n")
                f.write(f"Key = {bytes_to_hex(key)}\n")
                f.write(f"Nonce = {bytes_to_hex(nonce)}\n")
                f.write(f"PT = {bytes_to_hex(pt)}\n")
                f.write(f"AD = {bytes_to_hex(ad)}\n")
                f.write(f"CT = {bytes_to_hex(ct_and_tag)}\n\n")

                count += 1

    print(f"[SUCCESS] Generated {count-1} NIST KAT vectors into '{filename}'")

if __name__ == "__main__":
    generate_kat_file()