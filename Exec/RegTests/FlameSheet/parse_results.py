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

direc = sys.argv[1]
machine =sys.argv[2]
nodes=[24,32,64,128,256]
data={}
for node in nodes:
    if (machine=="frontier"):
        files = np.sort(glob.glob("%s/pelelmex_NODES_%d_GPN_8_GAM_1_CFRHS_1_2_TRIAL_*.out"%(direc,node)))
    else:
        files = np.sort(glob.glob("%s/pelelmex_NODES_%d_GPN_4_GAM_1_XNACK_1_THP_1_DEFRAG_1_CFRHS_1_2_TRIAL_*.out"%(direc,node)))

    times=[]
    for f in files:
        with open(f) as fp:
            lines = fp.readlines()
            time=0
            found=False
            for line in lines:
                if (line.find("NEW TIME STEP")>=0):
                    found = True
                    continue
                    
                if (found==True and line.find(">> PeleLMeX::Advance() --> Time:")>=0):
                    x = float(line.split(" ")[-1])
                    time = time+x
                if (found==True and line.find(">> PeleLM::Advance() --> Time:")>=0):
                    x = float(line.split(" ")[-1])
                    time = time+x
            times.append(time)
    data[node]=times
                  
    print(node,np.mean(times),np.min(times),np.max(times))

df = pd.DataFrame(data)
print(df)
df.to_csv("%s/times.csv"%direc,index=False)
