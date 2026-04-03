import sys
with open(sys.argv[1], "r") as f:
    src = f.read()

if "is_active: u.is_active," not in src:
    old = "      branch_ids: [],\n    });"
    new = "      branch_ids: [],\n      is_active: u.is_active,\n    });"
    if old in src:
        src = src.replace(old, new, 1)
        print("  patched: Users is_active in openEdit")

old_sw = "    Promise.all(promises).then(() => {\n      assignMutation.mutate({ userId: editing.id, branchId });\n    });"
new_sw = "    Promise.all(promises)\n      .then(() => { assignMutation.mutate({ userId: editing.id, branchId }); })\n      .catch((e) => { setError(\"Failed to switch branch: \" + (e?.response?.data?.error || e.message)); });"
if old_sw in src:
    src = src.replace(old_sw, new_sw)
    print("  patched: Users switchEditBranch error handling")

with open(sys.argv[1], "w") as f:
    f.write(src)

