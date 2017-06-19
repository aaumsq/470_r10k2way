#!/usr/bin/env python2
from subprocess import call, check_output
import sys
import os.path
import pickle
import re
import traceback
import numpy as np
import matplotlib.pyplot as plt
import pprint

colors = ['b', 'y', 'g', 'r', 'c', 'm', 'k', 'w']

def graph(words):
	stat = "time"
	if((words[0] == "cycles") or (words[0] == "instructions")
			or (words[0] == "CPI") or (words[0] == "time")):
		stat = words[0]
		words = words[1:]
	data = {}
	ntests = 0
	tests = []
	for filename in words:
		with open(filename+".pkl", 'rb') as f:
			results = pickle.load(f)
			#pprint.PrettyPrinter().pprint(results)
			for result in results:
				#pprint.PrettyPrinter().pprint(result)
				if result["name"] not in data:
					data[result["name"]] = {}
					for filenamej in words:
						data[result["name"]][filenamej] = 0
					ntests += 1
					tests.append(result["name"])
				data[result["name"]][filename] = result[stat]
	pprint.PrettyPrinter().pprint(data)
	width = 0.7/len(words)
	plt.rcParams["figure.figsize"] = [20, 5]
	fig, ax = plt.subplots()
	rects = {}
	ind = np.arange(ntests)
	i = 0
	legendrects = []
	legendlabels = []
	for filename in words:
		results = []
		for test in tests:
			results.append(data[test][filename])
		rects[filename] = ax.bar(ind + i*width, results, width, color=colors[i])
		legendrects.append(rects[filename][0])
		legendlabels.append(filename) 
		i += 1
	ax.set_ylabel(stat)
	ax.set_xticks(ind+width/2*len(words))
	ax.set_xticklabels(tests)
	ax.legend(legendrects, legendlabels)
	plt.tight_layout(0.1)
	plt.show()

tests = []
if os.path.isfile("perftests.pkl"):
	with open("perftests.pkl", 'rb') as f:
		tests = pickle.load(f)
configs = []

while True:
	line = raw_input(":")
	words = line.split()
	try:
		if line[0] == "!":
			call(line[1:])
			continue
		if len(words) == 0:
			continue
		if (words[0] == "quit") or (words[0] == "q"):
			break
		elif words[0] == "add" and (len(words) == 3):
			if words[1] == "test":
				test = words[2]
				tests.append(test)
			elif words[1] == "config":
				config = words[2]
				configs.append(config)
			else:
				print("Invalid command")
		elif words[0] == "remove" and (len(words) == 3):
			if words[1] == "test":
				tests.remove(words[2])
			elif (words[1] == "config") and (words[2] != "perftests"):
	#			if os.path.isfile(words[2] + ".pkl"):
				call(["rm", words[2] + ".pkl"])
	#			else:
	#				print("file doesn't exist")
			else:
				print("Invalid command")
		elif words[0] == "list" and words[1] == "tests":
			pprint.PrettyPrinter().pprint(tests)
		elif words[0] == "createbaseline":
			call("./createbaseline")
		elif words[0] == "run" and (len(words) == 2) and (words[1] != "perftests"):
			config = words[1]
			print("running configuration " + config)
			call("./build")
			worked = raw_input("Did the build work? ")
			if (worked == "y") or (worked == "yes") or (worked == ""):
				results = []
				print("testing: ")
				print(tests)
				for test in tests:
					output = check_output(["./perf", test])
					passed = "PASSED" in output
					numbers = re.findall("[-+]?\d+[\.]?\d*", output)
					results.append({
						"name": test,
						"cycles": int(numbers[0]),
						"instructions": int(numbers[1]),
						"CPI": float(numbers[2]),
						"time": float(numbers[3])
					})
					print(test +":\n")
					print(output + "\n")
				with open(config + ".pkl", 'wb') as f:
					pickle.dump(results, f)
		elif (words[0] == "graph") and (len(words) >= 2):
			graph(words[1:])
		else:
			print("Invalid command")
	except Exception as e:
		print(traceback.format_exc())

with open("perftests.pkl", 'wb') as f:
	pickle.dump(tests, f)
