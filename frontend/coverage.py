import re

with open("coverage/lcov.info", "r") as f:
    content = f.read()

# Desglòs per fitxer
sections = content.split("SF:")
results = []

for section in sections[1:]:  # skip primer element buit
    lines = section.strip().split("\n")
    filename = lines[0].strip()
    
    lf = next((int(x.split(":")[1]) for x in lines if x.startswith("LF:")), 0)
    lh = next((int(x.split(":")[1]) for x in lines if x.startswith("LH:")), 0)
    
    if lf > 0:
        pct = lh / lf * 100
        results.append((pct, lh, lf, filename))

# Ordenat de menor a major cobertura
results.sort()

print(f"{'Cobertura':<12} {'LH':<8} {'LF':<8} Fitxer")
print("-" * 80)
for pct, lh, lf, fname in results:
    # Escurça el path per llegibilitat
    short = fname.split("lib/")[-1] if "lib/" in fname else fname
    flag = " ⚠️" if pct < 50 else ""
    print(f"{pct:>8.1f}%   {lh:<8} {lf:<8} {short}{flag}")

# Totals
lf_total = sum(r[2] for r in results)
lh_total = sum(r[1] for r in results)
pct_total = lh_total / lf_total * 100
print("-" * 80)
print(f"{pct_total:>8.1f}%   {lh_total:<8} {lf_total:<8} TOTAL")