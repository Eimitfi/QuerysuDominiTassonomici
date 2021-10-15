//
//  ResultTaxonomy.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 15/09/2021.
//

import Foundation

enum GerarchyError:Error{
    case nodeWithoutLevelFound
    case ValueNotFoundInMapping(value:String)
    case TheGivenIdMappingIsNotCompatible
}

class IdentifierCreator{
    private var currentIdentifier = 0
    func getCurrent() -> Int{
        currentIdentifier += 1
        return currentIdentifier - 1
    }
}

class UnlevelledGerarchy<T:GerarchyElement>{
    
    var nodes:Set<Int> = Set<Int>()
    var valuesDirectlyBelow:[Int:Set<Int>] = [:]
    var valuesAbove:[Int:Set<Int>] = [:]
    var valuesBelow:[Int:Set<Int>] = [:]
    //usabile per risparmiare memoria in caso di elementi della gerarchia molto pesanti
    var IdToActualNodeMapping:[Int:T] = [:]
    
    func initializeNodes(nodes:[Int]){
        for node in nodes{
            if self.valuesDirectlyBelow[node] == nil {
                self.valuesDirectlyBelow[node] = Set<Int>()
            }
            
            if self.valuesBelow[node] == nil {
                self.valuesBelow[node] = Set<Int>()
            }
            if self.valuesAbove[node] == nil {
                self.valuesAbove[node] = Set<Int>()
            }
        }
    }
    
    public func getNodes() -> Set<T>{
        return Set<T>(self.IdToActualNodeMapping.values)
    }
    
    func getDirectlyAboveNodes(of node:Int) -> Set<Int>{
        var res:Set<Int> = Set<Int>()
        if !self.getAboveNodes(of: node).isEmpty{
            for aboveNode in self.getAboveNodes(of: node){
                if self.IsDirectlyBelow(node: aboveNode, belowNode: node){
                    res.insert(aboveNode)
                }
            }
        }
        return res
    }
    
    public func valueToId(value:T) -> Int{
        for (id,elem) in self.IdToActualNodeMapping{
            if elem == value {
                return id
            }
        }
        return -1
    }
    
    public func getMapping() -> [Int:T]{
        return self.IdToActualNodeMapping
    }
    
    public func getMappedNode(id:Int) -> T{
        return self.IdToActualNodeMapping[id]!
    }
    
    public func getMappedNodes(ids:Set<Int>) -> Set<T>{
        var result = Set<T>()
        for id in ids{
            result.insert(self.IdToActualNodeMapping[id]!)
        }
        return result
    }
    
    func getDirectlyBelowNodes(of node:Int) -> Set<Int>{
        var res:Set<Int> = Set<Int>()
        if self.valuesDirectlyBelow[node] != nil {
            res = self.valuesDirectlyBelow[node]!
        }
        return res
    }
    
    func getBelowNodes(of node:Int) -> Set<Int>{
        var res:Set<Int> = Set<Int>()
        if self.valuesBelow[node] != nil {
            res = self.valuesBelow[node]!
        }
        return res
    }
    
    func getAboveNodes(of node:Int) -> Set<Int>{
        var res:Set<Int> = Set<Int>()
        if self.valuesAbove[node] != nil {
            res = self.valuesAbove[node]!
        }
        return res
    }
    
    func getTopValues() -> Set<Int> {
        return self.nodes.filter({self.valuesAbove[$0]!.isEmpty})
    }
    
    func isAbove(node:Int,aboveNode:Int) -> Bool{
        return self.getAboveNodes(of: node).contains(aboveNode)
    }
    
    func isBelow(node:Int, belowNode:Int) -> Bool {
        return self.getBelowNodes(of: node).contains(belowNode)
    }
    
    func IsDirectlyBelow(node:Int, belowNode:Int) -> Bool {
        return self.getDirectlyBelowNodes(of: node).contains(belowNode)
    }
    
    init(){
        
    }
    
    func assignId(idCreator:IdentifierCreator,value:T) -> Int{
        let res:Int
        if Set<T>(self.IdToActualNodeMapping.values).contains(value){
            res = try! self.fromValueToId(value: value)
        }else{
            res = idCreator.getCurrent()
        }
        return res
    }
    
    public init(relationsBetweenNodes:[HigherThanRelation<T>]){
        let identifierCreator = IdentifierCreator.init()
        for relation in relationsBetweenNodes{
            let higher = relation.getHigherElement()
            let higherId = self.assignId(idCreator: identifierCreator, value: higher)
            let lower = relation.getLowerElement()
            let lowerId = self.assignId(idCreator: identifierCreator, value: lower)
            self.initializeNodes(nodes: [higherId,lowerId])
            self.IdToActualNodeMapping[higherId] = higher
            self.IdToActualNodeMapping[lowerId] = lower
            self.nodes.insert(higherId)
            self.nodes.insert(lowerId)
            self.valuesBelow[higherId]?.insert(lowerId)
            self.valuesAbove[lowerId]?.insert(higherId)
            self.valuesDirectlyBelow[higherId]?.insert(lowerId)
        }
        
        for node in self.nodes{
            for belowNode in self.getBelowNodes(of: node) {
                for secondLevelBelow in self.getBelowNodes(of: belowNode) {
                    if self.IsDirectlyBelow(node: node, belowNode: secondLevelBelow){
                        self.valuesDirectlyBelow[node]!.remove(secondLevelBelow)
                    }
                }
            }
        }
    }
    
    func fromValueToId(value:T) throws -> Int{
        for (id,val) in self.IdToActualNodeMapping{
            if val == value{
                return id
            }
        }
        throw GerarchyError.ValueNotFoundInMapping(value: value.description)
    }
    
    static private func getNodesWithLeveln(levels:[Int:Int],level:Int) -> Set<Int>{
        var res = Set<Int>()
        for (val,lev) in levels{
            if lev == level{
                res.insert(val)
            }
        }
        return res
    }
    
    func computeLevels() -> [T:Int]{
        var res:[Int:Int] = [:]
        var realRes:[T:Int] = [:]
        var actualLevel = 1
        for node in self.getTopValues() {
            res[node] = 0
        }
        
        while !UnlevelledGerarchy.getNodesWithLeveln(levels: res, level: actualLevel - 1).flatMap({self.getBelowNodes(of: $0) }).isEmpty {
            
            var actualLevelNodes = Set<Int>(UnlevelledGerarchy.getNodesWithLeveln(levels: res, level: actualLevel - 1).flatMap({self.getDirectlyBelowNodes(of: $0)}))
            
            for node in actualLevelNodes{
                if !Set<Int>(res.keys).isSuperset(of: self.getAboveNodes(of: node)) {
                    actualLevelNodes.remove(node)
                }
            }
            
            for node in actualLevelNodes{
                res[node] = actualLevel
            }
            
            actualLevel += 1
        }
        for (val,level) in res{
            realRes[self.IdToActualNodeMapping[val]!] = level
        }
        return realRes
    }
    
}

class Gerarchy<R:GerarchyElement, T:LevelledGerarchyElement<R>>:UnlevelledGerarchy<T>{
    //mantieni la stessa struttura ma aggiungi i livelli
    init(gerarchy:UnlevelledGerarchy<R>) throws {
        super.init()
        let levels = gerarchy.computeLevels()
        if Set<R>(levels.keys) != gerarchy.getNodes(){
            throw GerarchyError.nodeWithoutLevelFound
        }
        self.IdToActualNodeMapping = try gerarchy.IdToActualNodeMapping.mapValues({try LevelledGerarchyElement.init(node: $0, level: levels[$0]!) as! T})
        self.nodes = gerarchy.nodes
        self.valuesAbove = gerarchy.valuesAbove
        self.valuesBelow = gerarchy.valuesBelow
        self.valuesDirectlyBelow = gerarchy.valuesDirectlyBelow
    }
    
    public override func getMappedNode(id:Int) -> T{
        return super.getMappedNode(id: id)
    }
    
    public override func getMappedNodes(ids:Set<Int>) -> Set<T>{
        return super.getMappedNodes(ids: ids)
    }
    
    private override init(){
        super.init()
    }
    
    override func getAboveNodes(of:Int) -> Set<Int>{
        return super.getAboveNodes(of: of)
    }
    
    override func getDirectlyAboveNodes(of:Int) -> Set<Int>{
        return super.getDirectlyAboveNodes(of: of)
    }
    
    public init(nodes:Set<Int>,valuesAbove:[Int:Set<Int>],valuesBelow:[Int:Set<Int>],valuesDirectlyBelow:[Int:Set<Int>],idMapping:[Int:T]){
        super.init()
        self.nodes = nodes
        self.valuesAbove = valuesAbove
        self.valuesBelow = valuesBelow
        self.valuesDirectlyBelow = valuesDirectlyBelow
        self.IdToActualNodeMapping = idMapping
    }
    
    convenience init(relationsBetweenNodes: [HigherThanRelation<R>]) throws{
        try self.init(gerarchy: UnlevelledGerarchy.init(relationsBetweenNodes: relationsBetweenNodes))
    }
    
    init(relationsBetweenNodes: [LevelledHigherThanRelation<R,T>]) {
        super.init()
        let idCreator = IdentifierCreator.init()
        for relation in relationsBetweenNodes{
            let higher = relation.higher
            let higherId = super.assignId(idCreator: idCreator, value: higher)
            let lower = relation.lower
            let lowerId = super.assignId(idCreator: idCreator, value: lower)
            super.initializeNodes(nodes: [higherId,lowerId])
            self.IdToActualNodeMapping[higherId] = higher
            self.IdToActualNodeMapping[lowerId] = lower
            self.nodes.insert(higherId)
            self.nodes.insert(lowerId)
            self.valuesBelow[higherId]?.insert(lowerId)
            self.valuesAbove[lowerId]?.insert(higherId)
            self.valuesDirectlyBelow[higherId]?.insert(lowerId)
        }
        for node in self.valuesDirectlyBelow.keys{
            self.valuesDirectlyBelow[node]! = self.valuesDirectlyBelow[node]!.filter({self.IdToActualNodeMapping[node]!.level - self.IdToActualNodeMapping[$0]!.level == -1})
        }
    }
    
    static public func changeValues<T:LevelledGerarchyElement<Z>,R:LevelledGerarchyElement<Y>,Z:GerarchyElement,Y:GerarchyElement>(gerarchy:Gerarchy<Z,T>,newIdMapping:[Int:R]) throws -> Gerarchy<Y,R>{
        if Set<Int>(gerarchy.IdToActualNodeMapping.keys) != Set<Int>(newIdMapping.keys){
            throw GerarchyError.TheGivenIdMappingIsNotCompatible
        }
        let res = Gerarchy<Y,R>.init()
        res.nodes = gerarchy.nodes
        res.valuesAbove = gerarchy.valuesAbove
        res.valuesBelow = gerarchy.valuesBelow
        res.valuesDirectlyBelow = gerarchy.valuesDirectlyBelow
        res.IdToActualNodeMapping = newIdMapping
        return res
    }
    
    static public func changeValues<T:GerarchyElement,R:GerarchyElement>(gerarchy:UnlevelledGerarchy<T>,newIdMapping:[Int:R]) throws -> UnlevelledGerarchy<R>{
        if Set<Int>(gerarchy.IdToActualNodeMapping.keys) != Set<Int>(newIdMapping.keys){
            throw GerarchyError.TheGivenIdMappingIsNotCompatible
        }
        let res = UnlevelledGerarchy<R>.init()
        res.nodes = gerarchy.nodes
        res.valuesAbove = gerarchy.valuesAbove
        res.valuesBelow = gerarchy.valuesBelow
        res.valuesDirectlyBelow = gerarchy.valuesDirectlyBelow
        res.IdToActualNodeMapping = newIdMapping
        return res
    }
    
    public func getHighestLevel() -> Int{
        return self.IdToActualNodeMapping.values.map({$0.getLevel()}).sorted().last!
    }
    
    public override func valueToId(value:T) -> Int{
        return super.valueToId(value: value)
    }
    
    private func getIdNodesWithLevelnth(levelnth:Int) -> Set<Int>{
        return Set<Int>(self.IdToActualNodeMapping.filter({$0.1.getLevel() == levelnth}).keys)
    }
    public func getNodesWithLevelnth(levelnth:Int) -> Set<T>{
        return Set<T>(self.IdToActualNodeMapping.filter({$0.1.getLevel() == levelnth}).values)
    }
}

extension Gerarchy:CustomStringConvertible{
    public var description: String {get{self.descr()}}
    
    private func printNode(node:T,str: inout String){
        str += "  " + node.description + " " +
            String(node.getLevel()) + "  "
    }
    
    private func printChain(node:Int, str: inout String){
        for child in self.valuesBelow[node]!.sorted(by: {self.IdToActualNodeMapping[$0]!.getLevel() < self.IdToActualNodeMapping[$1]!.getLevel()}){
            self.printNode(node: self.IdToActualNodeMapping[child]!, str: &str)
            str += "|>"
        }
    }
   private func descr() -> String{
        var str = ""
        var index = 0
        while index <= self.getHighestLevel(){
            for topNode in self.getIdNodesWithLevelnth(levelnth: index){
                str += "chain of :\(self.IdToActualNodeMapping[topNode]!) ->"
                self.printChain(node: topNode, str: &str)
                str += "\n"
            }
            index += 1
        }
        return str
    }
}

