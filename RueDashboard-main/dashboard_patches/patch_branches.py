import sys
with open(sys.argv[1], "r") as f:
    src = f.read()

old1 = "      printer_ip:   branch.printer_ip || \"\",\n      printer_port: branch.printer_port || 9100,\n    });"
new1 = "      printer_ip:   branch.printer_ip || \"\",\n      printer_port: branch.printer_port || 9100,\n      is_active:    branch.is_active ?? true,\n    });"
if old1 in src:
    src = src.replace(old1, new1)
    print("  patched: Branches is_active in openEdit")

old2 = "    const payload = {"
new2 = """    // Validate printer IP
    if (form.printer_ip) {
      const ipRe = /^(\\d{1,3}\\.){3}\\d{1,3}$/;
      if (!ipRe.test(form.printer_ip)) { setError("Invalid printer IP format"); return; }
      if (form.printer_ip.split(".").some((o) => parseInt(o) > 255)) { setError("Invalid printer IP (octet > 255)"); return; }
    }
    const payload = {"""
if old2 in src and "Invalid printer IP" not in src:
    src = src.replace(old2, new2, 1)
    print("  patched: Branches IP validation")

with open(sys.argv[1], "w") as f:
    f.write(src)

