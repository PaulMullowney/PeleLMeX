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
    print(nodes[-1],vals[-1])
plt.errorbar(nodes,vals,yerr=[minerr, maxerr],fmt='ro-',label='MI300A (Tuolumne)',capsize=5, capthick=1)

nodes=[]
vals=[]
minerr=[]
maxerr=[]
for series_name, series in df2.items():
    nodes.append(int(series_name))
    vals.append(np.mean(series))
    minerr.append(vals[-1]-np.min(series))
    maxerr.append(np.max(series)-vals[-1])
    print(nodes[-1],vals[-1])
plt.errorbar(nodes,vals,yerr=[minerr, maxerr],fmt='rx--',label='MI300A (Tuolumne) with input file optimizations',capsize=5, capthick=1)

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
ax.set_yticks([50,60,70,80,90,100,110,120,130],['50','60','70','80','90','100','110','120','130'])
plt.grid()
fig.savefig("Pele_Figure6.png")
