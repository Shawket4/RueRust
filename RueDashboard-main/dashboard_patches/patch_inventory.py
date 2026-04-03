import sys, re
with open(sys.argv[1], "r") as f:
    src = f.read()

lines = [l for l in src.splitlines(keepends=True) if "console.log" not in l]
src = "".join(lines)
print("  patched: Inventory console.logs removed")

old = "function SoftServeTab({ branchId, orgId }) {"
new = """function SoftServeTab({ branchId, orgId }) {
  if (!orgId) return (
    <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-12 text-center text-gray-400 text-sm">
      No organization assigned to your account. Contact your administrator.
    </div>
  );"""
if old in src and "No organization assigned" not in src:
    src = src.replace(old, new)
    print("  patched: SoftServeTab orgId guard")

with open(sys.argv[1], "w") as f:
    f.write(src)

