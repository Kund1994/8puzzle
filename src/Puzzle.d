/**
	Puzzle window
	
	Copyright: © 2012 Oleh Havrys
	License: Subject to the terms of the MIT license, as written in the included LICENSE file.
	Authors: Oleh Havrys
*/
module Puzzle;

import gtk.Button;
import gtk.Main;
import gtk.Widget;
import gtk.Window;
import gtk.Builder;
import gtk.TextView;
import gtk.TextBuffer;
import gtk.TextIter;
import gtk.ComboBox;
import gtk.SpinButton;
import gtk.Adjustment;
import gtk.RadioButton;

import std.stdio;
import std.c.process : exit;
import std.random : randomShuffle, uniform;
import std.string : format;
import std.container : DList, Array;

import std.datetime;

import ai.Core;

class Puzzle {
	
	//TODO: lock calculation button
	
	string gladeFile = "8puzzle.glade";
	bool useShuffle = false;
	
	m3 lowPuzzle = [
		[1, 2, 5],
		[3, 4, 0],
		[6, 7, 8],
	];
	
	m3 midPuzzle = [
		[1, 4, 2],
		[7, 5, 8],
		[3, 0, 6]
	];
	
	//text panel
	TextView textView;
	TextIter textIter;
	
	ComboBox puzzleBox;
	SpinButton depthSpin;
	SpinButton memorySpin;
	SpinButton timeSpin;
	SpinButton countSpin;
	
	RadioButton radioLow;
	RadioButton radioMid;
	RadioButton radioRand; 
	RadioButton radioAlgo;
	RadioButton radioAlgo2;
	
	
	this() {
	}
	
	void show(string[] args) {
		Main.init(args);
		
		Builder g = new Builder();


		if(!g.addFromFile(gladeFile)) {
			writeln("Could not create Glade object, check your glade file.");
			exit(1);
		}
		
		Window w = cast(Window)g.getObject("pwindow");
		
		if (w !is null) {
			w.setTitle("8 Puzzle. Oleh Havrys");
			w.addOnHide(delegate void(Widget aux){ exit(0); });
			
			Button solveButton = cast(Button)g.getObject("psolvebutton");
			if(solveButton !is null) {
				solveButton.addOnClicked(&solveButtonClicked);
			}
			Button clearButton = cast(Button)g.getObject("pclearbutton");
			if(clearButton !is null) {
				clearButton.addOnClicked(&clearButtonClicked);
			}
			Button testButton = cast(Button)g.getObject("pruntest");
			if(testButton !is null) {
				testButton.addOnClicked(&testButtonClicked);
			}
			
			textView = cast(TextView)g.getObject("pview");
			
			depthSpin = cast(SpinButton)g.getObject("pdepthspin");
			depthSpin.setAdjustment(new Adjustment(10, 1, 20, 1, 10, 0));
			
			memorySpin = cast(SpinButton)g.getObject("pmemoryspin");
			memorySpin.setAdjustment(new Adjustment(0, 0, 50000000, 1, 10, 0));
			
			timeSpin = cast(SpinButton)g.getObject("ptimespin");
			timeSpin.setAdjustment(new Adjustment(0, 0, 50000000, 1, 10, 0));
			
			countSpin = cast(SpinButton)g.getObject("pcyclecount");
			countSpin.setAdjustment(new Adjustment(1, 1, 25, 1, 10, 0));
			
			radioLow = cast(RadioButton)g.getObject("pradio");
			radioMid = cast(RadioButton)g.getObject("pradiomid");
			radioRand = cast(RadioButton)g.getObject("pradiorandom");
			radioAlgo = cast(RadioButton)g.getObject("pradioalgo");
			radioAlgo2 = cast(RadioButton)g.getObject("pradioalgo2");
			
			textIter = new TextIter();
		} else {
			writeln("No window.");
			exit(1);
		}
		
		w.showAll();
		Main.run();
	}
	
	m3 generatePuzzle() {
		m3 pz;
		
		if(useShuffle) {
			int[] a = [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ];
			randomShuffle(a);
			int i=0;
			foreach (el; a) {
				pz[i/3][i%3] = el;
				i++;
			}
		} else {
			pz = solvedPuzzle;
			uint steps = uniform(2, 8);
			
			int zi, zj = 0; // zero coord
			int prevMove = -1;
			for(uint i=0;i<steps;i++) {
				int gto = getNextPuzzleMove(zi, zj, prevMove);
				
				switch(gto) {
					case 0: {
						pz[zi][zj] = pz[zi][zj-1];
						zj -= 1;
						pz[zi][zj] = 0;
						break;
					}
					case 1: {
						pz[zi][zj] = pz[zi+1][zj];
						zi += 1;
						pz[zi][zj] = 0;
						break;
					}
					case 2: {
						pz[zi][zj] = pz[zi][zj+1];
						zj += 1;
						pz[zi][zj] = 0;
						break;
					}
					case 3: {
						pz[zi][zj] = pz[zi-1][zj];
						zi -= 1;
						pz[zi][zj] = 0;
						break;
					}
					default: {
						
					}
				}
				
				prevMove = gto;
			}
		}
		
		return pz;
	}
	/**
	 * 0-up
	 * 1-right
	 * 2-down
	 * 3-left
	 */
	int getNextPuzzleMove(int i, int j, int prev) {
		int[] p;
		p.length = 0;
		if(i>=0 && i<2 && prev!=3) {
			p.length += 1;
			p[p.length-1] = 1;
		}
		if(j>=0 && j<2 && prev!=0) {
			p.length += 1;
			p[p.length-1] = 2;
		}
		if(i<=2 && i>0  && prev!=1) {
			p.length += 1;
			p[p.length-1] = 3;
		}
		if(j<=2 && j>0  && prev!=2) {
			p.length += 1;
			p[p.length-1] = 0;
		}
		
		return p[uniform(0, p.length)];
	}
	
	void solveButtonClicked(Button button) {
		textView.getBuffer().setText("");
		
		textView.getBuffer().getEndIter(textIter);
		
		// get data
		m3 puzzle;
		uint maxDepth = 1;
		uint maxMemory = 0;
		uint maxTime = 0;
		
		if(radioLow.getActive()) {
			puzzle = this.lowPuzzle;
		} else if(radioMid.getActive()) {
			puzzle = this.midPuzzle;
		} else {
			puzzle = this.generatePuzzle();
		}
		
		maxDepth = depthSpin.getValueAsInt();
		maxMemory = memorySpin.getValueAsInt();
		maxTime = timeSpin.getValueAsInt();
		
		// print input data
		textView.getBuffer().insert(textIter, "Input data:\n---------------\n");
		for(int i=0;i<3;i++) {
			for(int j=0;j<3;j++) {
				textView.getBuffer().insert(textIter, format("%s\t", puzzle[i][j]));
			}
			textView.getBuffer().insert(textIter, "\n");
		}
		textView.getBuffer().insert(textIter, "---------------\n");
		
		// solving
		textView.getBuffer().insert(textIter, "Solution:\n---------------\n");
		
		if(radioAlgo.getActive()) {
			solveLDFS(puzzle, maxDepth, maxMemory, maxTime);
		} else if(radioAlgo2.getActive()) {
			solveRBFS(puzzle, maxDepth, maxMemory, maxTime);
		} else {
			solveSA(puzzle);
		}
	}
	
	void clearButtonClicked(Button button) {
		textView.getBuffer().setText("");
	}
	
	void testButtonClicked(Button button) {
		int co = countSpin.getValueAsInt();
		int timeLim = 30;
		
		
		textView.getBuffer().setText("");
		textView.getBuffer().getEndIter(textIter);
		
		auto startTime = Clock.currTime();
		
		textView.getBuffer().insert(textIter, format("Running a test run algorithms:\nLDFS and RBFS execution time is limited to %s sec\nStart at %s\n", timeLim, startTime));
		textView.getBuffer().insert(textIter, "---------------------------------------------------------------------------\n");
		
		Array!TestResult results;
		
		int a1 = 0;
		int a2 = 0;
		int a3 = 0;
		
		
		TestResult rSum;
		
		for(int i=0;i<co;i++) {
			PuzzleProblem problem = new PuzzleProblem(this.generatePuzzle(), solvedPuzzle);
			TestResult res;
			//1
			DepthLimitedSearch dls = new DepthLimitedSearch(9);
			dls.setTimeLimit(timeLim);
			dls.search(problem);
			if(dls.getError() == Search.NO_ERROR) {
				res.a1Solved = true;
				a1++;
				
				rSum.a1Cost += dls.pathCost;
				rSum.a1Time += dls.timeUsed;
				rSum.a1Nodes += dls.expandedNodes;
				rSum.a1Mem += (dls.expandedNodes*(cast(uint)Node.classinfo.init.length));
			} else {
				writeln(format("1.err=%s", dls.getError()));
			}
			res.a1Cost = dls.pathCost;
			res.a1Time = dls.timeUsed;
			res.a1Nodes = dls.expandedNodes;
			res.a1Mem = (dls.expandedNodes*(cast(uint)Node.classinfo.init.length));
			//2
			BestFirstSearch bfs = new BestFirstSearch();
			bfs.setTimeLimit(timeLim);
			bfs.search(problem);
			if(bfs.getError() == Search.NO_ERROR) {
				res.a2Solved = true;
				a2++;
				
				rSum.a2Cost += bfs.pathCost;
				rSum.a2Time += bfs.timeUsed;
				rSum.a2Nodes += bfs.expandedNodes;
				rSum.a2Mem += (bfs.expandedNodes*(cast(uint)Node.classinfo.init.length));
			} else {
				writeln(format("2.err=%s", bfs.getError()));
			}
			res.a2Cost = bfs.pathCost;
			res.a2Time = bfs.timeUsed;
			res.a2Nodes = bfs.expandedNodes;
			res.a2Mem = (bfs.expandedNodes*(cast(uint)Node.classinfo.init.length));
			//3
			SimulatedAnnealingSearch sa = new SimulatedAnnealingSearch();
			Shedule shed = new Shedule(0.1);
			sa.search(problem, shed);
			if(sa.isSolved()) {
				res.a3Solved = true;
				a3++;
				
				rSum.a3Cost += sa.pathCost;
				rSum.a3Time += sa.timeUsed;
				rSum.a3Nodes += sa.expandedNodes;
				rSum.a3Mem += (sa.expandedNodes*(cast(uint)Node.classinfo.init.length));
			}
			res.a3Cost = sa.pathCost;
			res.a3Time = sa.timeUsed;
			res.a3Nodes = sa.expandedNodes;
			res.a3Mem = (sa.expandedNodes*(cast(uint)Node.classinfo.init.length));
			
			textView.getBuffer().insert(textIter, format("%s.\n", i));
			
			textView.getBuffer().insert(textIter, format("LDFS: %s, Time: %s, Cost: %s, Nodes: %s Mem: %s;\n", res.a1Solved?"Solved":"Unsolved", res.a1Time, res.a1Cost, res.a1Nodes, res.a1Mem));
			textView.getBuffer().insert(textIter, format("RBFS: %s, Time: %s, Cost: %s, Nodes: %s Mem: %s;\n", res.a2Solved?"Solved":"Unsolved", res.a2Time, res.a2Cost, res.a2Nodes, res.a2Mem));
			textView.getBuffer().insert(textIter, format("SA: %s, Time: %s, Cost: %s, Nodes: %s Mem: %s;\n", res.a3Solved?"Solved":"Unsolved", res.a3Time, res.a3Cost, res.a3Nodes, res.a3Mem));
			textView.getBuffer().insert(textIter, "---------------------------------------------------------------------------\n");
		}
			
		textView.getBuffer().insert(textIter, "The average value for solved:\n");
		textView.getBuffer().insert(textIter, "---------------------------------------------------------------------------\n");
		textView.getBuffer().insert(textIter, format("LDFS: %s, Time: %s, Cost: %s, Nodes: %s Mem: %s;\n", a1, (a1>0)?(rSum.a1Time/a1):rSum.a1Time, (a1>0)?rSum.a1Cost/a1:0, (a1>0)?rSum.a1Nodes/a1:0, (a1>0)?rSum.a1Mem/a1:0));
		textView.getBuffer().insert(textIter, format("RBFS: %s, Time: %s, Cost: %s, Nodes: %s Mem: %s;\n", a2, (a2>0)?(rSum.a2Time/a2):rSum.a2Time, (a2>0)?rSum.a2Cost/a2:0, (a2>0)?rSum.a2Nodes/a2:0, (a2>0)?rSum.a2Mem/a2:0));
		textView.getBuffer().insert(textIter, format("SA: %s, Time: %s, Cost: %s, Nodes: %s Mem: %s;\n", a3, (a3>0)?(rSum.a3Time/a3):rSum.a3Time, (a3>0)?rSum.a3Cost/a3:0, (a3>0)?rSum.a3Nodes/a3:0, (a3>0)?rSum.a3Mem/a3:0));	
		textView.getBuffer().insert(textIter, "---------------------------------------------------------------------------\n");
	}
	
	void solveLDFS(m3 puzzle, uint md, uint mm, uint mt) {
		auto startTime = Clock.currTime();
		textView.getBuffer().insert(textIter, format("Running LDFS algorithm:\nStart at %s\n", startTime));
		
		PuzzleProblem problem = new PuzzleProblem(puzzle, solvedPuzzle);
		DepthLimitedSearch dls = new DepthLimitedSearch((md<=0)?9:md);
		dls.setTimeLimit(mt);
		dls.setMemoryLimit(mm);
		
		DList!Action sa = dls.search(problem);
		
		auto endTime = Clock.currTime();
		textView.getBuffer().insert(textIter, format("Finished %s at %s\n---------------\n", ((dls.getError()!=0)?"unsuccessfully":"successfully"), endTime));
		
		textView.getBuffer().insert(textIter, format("Statistics:\n---------------\nTime taken: %s\nNodes opened: %s\nMemory used: %s bytes\nPath cost: %s\n---------------\n", 
				dls.timeUsed, dls.expandedNodes, (dls.expandedNodes*(cast(uint)Node.classinfo.init.length)), dls.pathCost));
		
		textView.getBuffer().insert(textIter, "Result:\n---------------\n");
		switch(dls.getError()) {
			case Search.NO_ERROR: {
				textView.getBuffer().insert(textIter, "Solution found\nSteps:\n---------------\n");
			
				m3 modPuzz = puzzle;
			
			
				foreach(ref act; sa) {
					modPuzz = problem.result(modPuzz, act);
					for(int i=0;i<3;i++) {
						for(int j=0;j<3;j++) {
							textView.getBuffer().insert(textIter, format("%s\t", modPuzz[i][j]));
						}
						textView.getBuffer().insert(textIter, "\n");
					}
					textView.getBuffer().insert(textIter, "---------------\n");
				}
				
				break;
			}
			case Search.LIMIT_TIME: {
				textView.getBuffer().insert(textIter, "Exceeded time limit\n");
				break;
			}
			case Search.LIMIT_DEPTH: {
				textView.getBuffer().insert(textIter, "Exceeded depth\n");
				break;
			}
			case Search.LIMIT_MEMORY: {
				textView.getBuffer().insert(textIter, "Exceeded memory limit\n");
				break;
			}
			default: {
				return;
			}
			
		}
		
	}
	
	void solveRBFS(m3 puzzle, uint md, uint mm, uint mt) {
		
		auto startTime = Clock.currTime();
		textView.getBuffer().insert(textIter, format("Running LDFS algorithm:\nStart at %s\n", startTime));
		
		PuzzleProblem problem = new PuzzleProblem(puzzle, solvedPuzzle);
		BestFirstSearch dls = new BestFirstSearch();
		dls.setTimeLimit(mt);
		dls.setMemoryLimit(mm);
		
		BFSResult sa = dls.search(problem);
		
		auto endTime = Clock.currTime();
		textView.getBuffer().insert(textIter, format("Finished %s at %s\n---------------\n", ((dls.getError()!=0)?"unsuccessfully":"successfully"), endTime));
		
		textView.getBuffer().insert(textIter, format("Statistics:\n---------------\nTime taken: %s\nNodes opened: %s\nMemory used: %s bytes\nPath cost: %s\nMaximum depth: %s\n---------------\n", 
				dls.timeUsed, dls.expandedNodes, (dls.expandedNodes*(cast(uint)Node.classinfo.init.length)), dls.pathCost, dls.limitUsed));
		
		textView.getBuffer().insert(textIter, "Result:\n---------------\n");
		switch(dls.getError()) {
			case Search.NO_ERROR: {
				textView.getBuffer().insert(textIter, "Solution found\nSteps:\n---------------\n");
			
				m3 modPuzz = puzzle;
			
			
				foreach(ref act; sa.actions) {
					modPuzz = problem.result(modPuzz, act);
					for(int i=0;i<3;i++) {
						for(int j=0;j<3;j++) {
							textView.getBuffer().insert(textIter, format("%s\t", modPuzz[i][j]));
						}
						textView.getBuffer().insert(textIter, "\n");
					}
					textView.getBuffer().insert(textIter, "---------------\n");
				}
				
				break;
			}
			case Search.LIMIT_TIME: {
				textView.getBuffer().insert(textIter, "Exceeded time limit\n");
				break;
			}
			case Search.LIMIT_DEPTH: {
				textView.getBuffer().insert(textIter, "Exceeded depth\n");
				break;
			}
			case Search.LIMIT_MEMORY: {
				textView.getBuffer().insert(textIter, "Exceeded memory limit\n");
				break;
			}
			default: {
				return;
			}
			
		}
	}
	
	void solveSA(m3 puzzle) {
		auto startTime = Clock.currTime();
		textView.getBuffer().insert(textIter, format("Running Simulate Annealing algorithm:\nStart at %s\n", startTime));
		
		PuzzleProblem problem = new PuzzleProblem(puzzle, solvedPuzzle);
		SimulatedAnnealingSearch sa = new SimulatedAnnealingSearch();
		Shedule shed = new Shedule(2);
		
		
		DList!Action res = sa.search(problem, shed);
		
		auto endTime = Clock.currTime();
		textView.getBuffer().insert(textIter, format("Finished %s at %s\n---------------\n", ((!sa.isSolved())?"unsuccessfully":"successfully"), endTime));
		
		textView.getBuffer().insert(textIter, format("Statistics:\n---------------\nTime taken: %s\nNodes opened: %s\nPath cost: %s\n---------------\n", 
				sa.timeUsed, sa.expandedNodes, sa.pathCost));
		
		textView.getBuffer().insert(textIter, "Result:\n---------------\n");
		
		if(sa.isSolved()) {
			textView.getBuffer().insert(textIter, "Solution found\nSteps:\n---------------\n");
			
				m3 modPuzz = puzzle;
			
			
				foreach(ref act; res) {
					modPuzz = problem.result(modPuzz, act);
					for(int i=0;i<3;i++) {
						for(int j=0;j<3;j++) {
							textView.getBuffer().insert(textIter, format("%s\t", modPuzz[i][j]));
						}
						textView.getBuffer().insert(textIter, "\n");
					}
					textView.getBuffer().insert(textIter, "---------------\n");
				}
		} else {
			textView.getBuffer().insert(textIter, "Solution not found\n");
		}
	}
	
}

struct TestResult {
	Duration a1Time;
	Duration a2Time;
	Duration a3Time;
	
	int a1Cost = 0;
	int a2Cost = 0;
	int a3Cost = 0;
	
	int a1Mem = 0;
	int a2Mem = 0;
	int a3Mem = 0;
	
	int a1Nodes = 0;
	int a2Nodes = 0;
	int a3Nodes = 0;
	
	
	bool a1Solved = false;
	bool a2Solved = false;
	bool a3Solved = false;
}