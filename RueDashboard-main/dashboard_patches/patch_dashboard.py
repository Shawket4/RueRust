import sys, re
with open(sys.argv[1], "r") as f:
    src = f.read()

# Move React import to top
src = re.sub(r"\nimport React from \"react\";\n", "\n", src)
if "import React from \"react\";" not in src[:50]:
    src = "import React from \"react\";\n" + src
    print("  patched: Dashboard React import at top")

src = src.replace(
    "instapay:       \"bg-purple-50 text-purple-700\"",
    "digital_wallet: \"bg-purple-50 text-purple-700\""
)
print("  patched: Dashboard instapay → digital_wallet")

src = src.replace(
    "queryKey: [\"recent-orders-branch-scan\", branches?.map((b) => b.id)]",
    "queryKey: [\"recent-orders-branch-scan\", branches?.map((b) => b.id).join(\",\")]"
)
print("  patched: Dashboard queryKey stable")

old_dup = "    { icon: GitBranch, label: \"Organizations\", value: orgs?.length,  sub: `${orgs?.filter(o => o.is_active).length ?? 0} active`, color: \"text-amber-600\", bg: \"bg-amber-50\", border: \"border-amber-100\",  loading: orgsLoading },"
new_dup = "    { icon: Users,     label: \"Active Staff\",  value: users?.filter(u => u.is_active).length, sub: \"Active accounts\", color: \"text-amber-600\", bg: \"bg-amber-50\", border: \"border-amber-100\", loading: usersLoading },"
if old_dup in src:
    src = src.replace(old_dup, new_dup)
    print("  patched: Dashboard dup stat → Active Staff")

src = re.sub(
    r"\n\s*// We'll use a single aggregated query approach\n\s*const queries = \(branches \?\? \[\]\)\.map\(\(b\) => \(\{.*?\}\)\);\n",
    "\n",
    src, flags=re.DOTALL
)
print("  patched: Dashboard dead queries variable removed")

with open(sys.argv[1], "w") as f:
    f.write(src)

