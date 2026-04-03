import sys
with open(sys.argv[1], "r") as f:
    src = f.read()
src = src.replace('from "../../store/auth"', 'from "../../store/auth.jsx"')
src = src.replace("from '../../store/auth'", "from '../../store/auth.jsx'")
with open(sys.argv[1], "w") as f:
    f.write(src)
print("  patched: Recipes auth import")

