/**
	Solving algorithms
	
	Copyright: © 2012 Oleh Havrys
	License: Subject to the terms of the MIT license, as written in the included LICENSE file.
	Authors: Oleh Havrys
*/
module ai.Core;

alias uint[3][3] m3;

import std.stdio;
import std.container;
import std.range;
import std.string;

import std.datetime;
import std.random;
import std.math;

const int INF = 9999999;

const m3 solvedPuzzle = [
		[0, 1, 2],
		[3, 4, 5],
		[6, 7, 8],	
	];

struct pos {
	uint i;
	uint j;
}

struct Action {
	pos from;
	pos to;
	bool cf = false; // cut off
	bool noop = false;
	
	this(bool cfVal, bool noopVal) {
		cf = cfVal;
		noop = noopVal;
		from = pos(0,0);
		to = pos(0,0);
	}
	
	this(pos fVal, pos tVal) {
		from = fVal;
		to = tVal;
	}
}

struct BFSResult {
	DList!Action actions;
	uint limit = INF;
	
	this(DList!Action ac, uint lim) {
		actions = ac;
		limit = lim;
	}
}

class PuzzleProblem {
	m3 initial;
	m3 goal;
	
	this(m3 initial, m3 goal) {
		this.initial = initial;
		this.goal = goal;
	}
	
	SList!Action actions(m3 state) {
		SList!Action act;
		
		int zi,zj=0;
		// find empty
		for(int i=0;i<3;i++) {
			for(int j=0;j<3;j++) {
				if(state[i][j] == 0) {
					zi = i;
					zj = j;
				}
			}
		}
		// find actions
		if(zi<2) {
			act.insert(Action(pos(zi+1, zj), pos(zi, zj)));
		}
		if(zi>0) {
			act.insert(Action(pos(zi-1, zj), pos(zi, zj)));
		}
		if(zj<2) {
			act.insert(Action(pos(zi, zj+1), pos(zi, zj)));
		}
		if(zj>0) {
			act.insert(Action(pos(zi, zj-1), pos(zi, zj)));
		}
		
		return act;
	}
	
	m3 result(m3 state, Action act) {
		m3 nstate = state;
		nstate[act.to.i][act.to.j] = nstate[act.from.i][act.from.j];
		nstate[act.from.i][act.from.j] = 0;
		return nstate;
	}
	
	bool goalTest(m3 state) {
		for(int i=0;i<3;i++) {
			for(int j=0;j<3;j++) {
				if(state[i][j] != this.goal[i][j]) {
					return false;
				}
			}
		}
		return true;
	}
	
	uint stepCost() {
		return 1;
	}
	
	m3 getInitialState() {
		return this.initial;
	}
	
}

class Node {
	
	private m3 state;
	private Node parent;
	private Action action;
	private uint pathCost;
	
	this(m3 state) {
		this.state = state;
		this.pathCost = 0;
	}
	
	this(m3 state, Node parent, Action action, uint stepCost) {
		this(state);
		this.parent = parent;
		this.action = action;
		this.pathCost = parent.pathCost + stepCost;
	}
	
	m3 getState() {
		return this.state;
	}
	
	Node getParent() {
		return this.parent;
	}
	
	Action getAction() {
		return this.action;
	}
	
	uint getPathCost() {
		return this.pathCost;
	}
	
	bool isRootNode() {
		return this.parent is null;
	}
	
	SList!Node getPathFromRoot() {
		SList!Node path;
		Node current = this;
		while(!current.isRootNode()) {
			path.insertFront(current);
			current = current.getParent();
		}
		
		path.insertFront(current);
		return path;
	}
	
	Node cpy(int stepCost) {
		return new Node(state, parent, action, stepCost);
	}
}

class Search {
	
	static const int NO_ERROR = 0;
	static const int LIMIT_TIME = 1;
	static const int LIMIT_DEPTH = 2;
	static const int LIMIT_MEMORY = 3;
	
	protected int errorCode = 0;
	
	protected uint timeLimit = 0;
	protected uint memoryLimit = 0;
	
	protected SysTime startTime;
	public Duration timeUsed;
	protected uint maxExpands = 0;
	
	protected DList!Action cutoffResult;
	
	// info
	public uint expandedNodes = 1;
	public uint pathCost = 0;
	public uint limitUsed = 0;
	
	int getError() {
		return errorCode;
	}
	
	void setError(uint ec) {
		errorCode = ec;
	}
	
	void setTimeLimit(uint tl) {
		timeLimit = tl;
	}
	
	void setMemoryLimit(uint ml) {
		memoryLimit = ml;
	}
	
	void startChecks() {
		startTime = Clock.currTime();
		maxExpands = memoryLimit/(cast(uint)Node.classinfo.init.length);
	}
	
	bool passChecks(int expNodes) {
		if(maxExpands > 0 && expNodes >= maxExpands) {
			setError(LIMIT_MEMORY);
			return false;
		}
		auto currentTime = Clock.currTime();
		auto diff = currentTime - startTime;
		
		if(timeLimit > 0 && diff.total!"seconds" >= timeLimit) {
			setError(LIMIT_TIME);
			return false;
		}	
		return true;
	}
	
	void endChecks() {
		auto currentTime = Clock.currTime();
		timeUsed = currentTime - startTime;
	}
	
	// methods
	
	bool isCutOff(DList!Action result) {
		return 1 == walkLength(result[]) && result.front().cf;
	}
	
	bool isFailure(DList!Action result) {
		return 0 == walkLength(result[]);
	}
	
	DList!Action actionsFromNodes(SList!Node nodeList) {
		DList!Action actions;
		if (walkLength(nodeList[]) == 1) {
			// I'm at the root node, this indicates I started at the
			// Goal node, therefore just return a NoOp
			actions.insertBack(Action(false, true));
		} else {
			// ignore the root node this has no action
			foreach(ref node; nodeList) {
				if(!node.isRootNode())
					actions.insertBack(node.getAction());
			}
		}
		return actions;
	}
	
	private DList!Action cutoff() {
		// Only want to created once
		if (this.cutoffResult.empty()) {
			this.cutoffResult.insert(Action(true, false));
		}
		return this.cutoffResult;
	}
	
	private DList!Action failure() {
		if (!this.cutoffResult.empty()) {
			this.cutoffResult.clear();
		}
		return this.cutoffResult;
	}
	
	Array!Node expandNode(Node node, PuzzleProblem problem) {
		Array!Node childNodes;
		foreach(ref action; problem.actions(node.getState())) {
			m3 successorState = problem.result(node.getState(),	action);
			uint stepCost = problem.stepCost();
			
			Node nn = new Node(successorState, node, action, stepCost);
			childNodes.insert(nn);
		}
		this.expandedNodes++;
		return childNodes;
	}
}

class DepthLimitedSearch : Search {
	
	private uint limit;
	
	this(uint limit) {
		this.limit = limit;
	}
	
	DList!Action search(PuzzleProblem p) {
		startChecks();
		return this.recursiveDLS(new Node(p.getInitialState()), p, this.limit);
	}
	
	DList!Action recursiveDLS(Node node, PuzzleProblem problem, uint lim) {
		// if is goal
		if (problem.goalTest(node.getState())) {
			this.limitUsed = this.limit - lim;
			this.pathCost = node.getPathCost();
			setError(NO_ERROR);
			endChecks();
			return this.actionsFromNodes(node.getPathFromRoot());
		} else if (lim == 0) {
			// depth limit
			setError(LIMIT_DEPTH);
			endChecks();
			return this.cutoff();
		} else {
			// else
			
			if(!passChecks(this.expandedNodes)) {
				endChecks();
				return this.failure();
			}
			
			bool cutoff_occurred = false;
			// expand sub nodes
			foreach(ref child; this.expandNode(node, problem)) {
				// use algo for sub nodes recursive
				DList!Action result = this.recursiveDLS(child, problem, lim - 1);
				if (this.isCutOff(result)) {
					// depth limit
					cutoff_occurred = true;
				} else if (!this.isFailure(result)) {
					// failure
					return result;
				}
			}
			// check cutoff
			if (cutoff_occurred) {
				setError(LIMIT_DEPTH);
				return this.cutoff();
			} else {
				return this.failure();
			}
		}
	}
	
}

class BestFirstSearch : Search {
	
	this() {
	}
	
	BFSResult search(PuzzleProblem p) {
		startChecks();
		Node n = new Node(p.getInitialState());
		return this.recursiveBFS(n, p, h(n.getState()), INF, 0);
	}
	
	BFSResult recursiveBFS(Node node, PuzzleProblem problem, int nodeF, int fLimit, int recursiveDepth) {
		
		if(recursiveDepth > limitUsed) limitUsed = recursiveDepth;
		
		// if is goal
		if (problem.goalTest(node.getState())) {
			this.pathCost = node.getPathCost();
			setError(NO_ERROR);
			endChecks();
			return BFSResult(this.actionsFromNodes(node.getPathFromRoot()), INF);
		} else {
			// else
			
			if(!passChecks(this.expandedNodes)) {
				endChecks();
				return BFSResult(this.failure(), INF);
			}
			
			Array!Node successors = this.expandNode(node, problem);
			int len = cast(int)successors.length();
			if(len == 0) BFSResult(this.failure(), INF);
			
			Array!int f;
			
			Node minFNode;
			
			bool first = true;
			int i=0;
			foreach(ref child; successors) {
				f.insert(max((h(child.getState()) + child.getPathCost()), nodeF));
				i++;
			}
			
			// expand sub nodes
			while(true) {
				int bestFIndex = getBestFIndex(f);
				if (f[bestFIndex] > fLimit) {
					return BFSResult(this.failure(), f[bestFIndex]);
				}
				int altFIndex = getNextBestFIndex(f, bestFIndex);
				BFSResult res = recursiveBFS(successors[bestFIndex], problem, f[bestFIndex], min(fLimit, f[altFIndex]), recursiveDepth + 1);
				f[bestFIndex] = res.limit;
				
				if(!isFailure(res.actions)) {
					return res;
				} else if(isFailure(res.actions) && res.limit == INF) {
					return res;
				}
			}
		}
	}
	
	int getBestFIndex(Array!int f) {
		int mini = 0;
		for(int i=0;i<f.length();i++) {
			if(f[mini] > f[i])
				mini = i;
		}
		return mini;
	}
	
	int getNextBestFIndex(Array!int f, int besti) {
		int mini = 0;
		for(int i=0;i<f.length();i++) {
			if(i != besti && f[mini] > f[i])
				mini = i;
		}
		return mini;
	}
	
	int h(m3 puzzle) {
		int h1 = 0;
		for(int i=0;i<3;i++) {
			for(int j=0;j<3;j++) {
				if(puzzle[i][j] != solvedPuzzle[i][j] && solvedPuzzle[i][j] != 0) {
					h1++;
				}
			}
		}
		return h1;
	}
	
	int max(int f, int m) {
		return f>m?f:m;
	}
	
	int min(int f, int m) {
		return f<m?f:m;
	}
	
}


class Shedule {
	float k;
	
	this() {
		this.k = 10;
	}
	
	this(float k) {
		this.k = k;
	}
	
	float getT(int t) {
		float T = 1000 - k*t;
		return (T>0)?T:0;
	}
}

class SimulatedAnnealingSearch : Search {
	
	private bool solved = false;
	
	this() {
	}
	
	bool isSolved() {
		return solved;
	}
	
	DList!Action search(PuzzleProblem p, Shedule shedule) {
		solved = false;
		
		startChecks();
		
		Node current = new Node(p.getInitialState());
		Node next = null;
		
		DList!Action ret;
		
		int t = 1;
		
		passChecks(this.expandedNodes);
		
		while(true) {
			float T = shedule.getT(t);
			if(T == 0 || p.goalTest(current.getState())) {
				if(p.goalTest(current.getState())) {
					solved = true;
				}
				this.pathCost = current.getPathCost();
				endChecks();
				return this.actionsFromNodes(current.getPathFromRoot());
			}
			Array!Node childs = this.expandNode(current, p);
			int len = cast(int)childs.length();
			if(len > 0) {
				next = childs[this.getRandom(len)];
				int dE = getValue(p, next) - getValue(p, current);
				if(shouldAccept(T, dE)) {
					current = next.cpy(p.stepCost());
				}
			}
			t++;
		}
	}
	
	int getRandom(int len) {
		Random gen = Random(unpredictableSeed);
		return cast(int)uniform(0, len-1, gen);
	}
	
	private int getValue(PuzzleProblem p, Node n) {
		// assumption greater heuristic value =>
		// HIGHER on hill; 0 == goal state;
		// SA deals with gardient DESCENT
		return -1 * h(n.getState());
	}
	
	int h(m3 puzzle) {
		int h1 = 0;
		for(int i=0;i<3;i++) {
			for(int j=0;j<3;j++) {
				if(puzzle[i][j] != solvedPuzzle[i][j] && solvedPuzzle[i][j] != 0) {
					h1++;
				}
			}
		}
		return h1;
	}
	
	public float probabilityOfAcceptance(float T, int dE) {
		return exp(cast(float)(dE/T));
	}
	
	private bool shouldAccept(float T, int dE) {
		auto gen = Random(unpredictableSeed);
		return (dE > 0) || (uniform(0.0f, 1.0f, gen) <= probabilityOfAcceptance(T, dE));
	}
	
}













