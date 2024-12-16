import numpy as np
import pandas as pd
import os
import sys
import glob
import json
import time
import bisect
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np

df1 = pd.read_csv(sys.argv[1])
df2 = pd.read_csv(sys.argv[2])

fig = plt.figure()
nodes=[]
vals=[]
minerr=[]
maxerr=[]
for series_name, series in df1.items():
    nodes.append(int(series_name))
    vals.append(np.mean(series))
    minerr.append(vals[-1]-np.min(series))
    maxerr.append(np.max(series)-vals[-1])
    print(nodes[-1],vals[-1],minerr[-1],maxerr[-1])
plt.errorbar(nodes,vals,yerr=[minerr, maxerr],fmt='ro-',label='MI300A (Tuolumne)',capsize=5, capthick=1)

nodes1=[]
vals1=[]
minerr1=[]
maxerr1=[]
for series_name, series in df2.items():
    nodes1.append(int(series_name))
    vals1.append(np.mean(series))
    minerr1.append(vals1[-1]-np.min(series))
    maxerr1.append(np.max(series)-vals1[-1])
    print(nodes1[-1],vals1[-1],minerr1[-1],maxerr1[-1])
plt.errorbar(nodes1,vals1,yerr=[minerr1, maxerr1],fmt='bo-',label='MI250X (Frontier)',capsize=5, capthick=1)

plt.xlabel("Nodes",fontsize=16)
plt.ylabel("Total Simulation Time",fontsize=16)
plt.title("PeleLMeX Performance on AMD GPUs",fontsize=20)
plt.legend()
ax = plt.gca()
ax.set_xscale('log')
ax.set_yscale('log')
ax.xaxis.set_minor_locator(plt.NullLocator())
ax.xaxis.set_major_locator(plt.NullLocator())
ax.yaxis.set_minor_locator(plt.NullLocator())
ax.yaxis.set_major_locator(plt.NullLocator())
ax.set_xticks(nodes)
nodestrs=[]
for n in nodes: nodestrs.append(str(n))
ax.set_xticks(nodes,nodestrs)
ax.set_yticks([50,60,70,80,90,100,110,120,130,140,150],['50','60','70','80','90','100','110','120','130','140','150'])
plt.grid()
fig.savefig("Pele_Figure5.png")
