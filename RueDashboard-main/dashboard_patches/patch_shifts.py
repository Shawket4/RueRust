import sys, re
with open(sys.argv[1], "r") as f:
    src = f.read()

old_q = """  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
    onSuccess: (data) => { if (data.length && !branchId) setBranchId(data[0].id); },
  });"""
new_q = """  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });
  React.useEffect(() => {
    if (branches.length && !branchId) setBranchId(branches[0].id);
  }, [branches]);"""
if old_q in src:
    src = src.replace(old_q, new_q)
    print("  patched: Shifts onSuccess → useEffect")

if "import React" not in src:
    src = "import React from \"react\";\n" + src
    print("  patched: Shifts React import added")

old_fc = """            {shift.status === "open" && <>
              <Btn variant="ghost" onClick={() => setShowCash(true)} style={{ fontSize: 12 }}>
                + Cash Movement
              </Btn>
              <Btn variant="danger" onClick={() => setShowForce(true)} style={{ fontSize: 12 }}>
                Force Close
              </Btn>
            </>}"""
new_fc = """            {shift.status === "open" && <>
              <Btn variant="ghost" onClick={() => setShowCash(true)} style={{ fontSize: 12 }}>
                + Cash Movement
              </Btn>
              {user?.role !== "teller" && (
                <Btn variant="danger" onClick={() => setShowForce(true)} style={{ fontSize: 12 }}>
                  Force Close
                </Btn>
              )}
            </>}"""
if old_fc in src:
    src = src.replace(old_fc, new_fc)
    print("  patched: Shifts Force Close hidden from tellers")

old_sd = "function ShiftDetail({ shift, branchName, onClose }) {"
new_sd = "function ShiftDetail({ shift, branchName, onClose }) {\n  const { user } = useAuth();"
if old_sd in src and "const { user } = useAuth();" not in src:
    src = src.replace(old_sd, new_sd, 1)
    print("  patched: Shifts ShiftDetail gets user")

with open(sys.argv[1], "w") as f:
    f.write(src)

