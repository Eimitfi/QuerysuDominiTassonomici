//
//  ResultAlgorithm.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 15/09/2021.
//

import Foundation

enum ModifiedLBAAlgorithmError:Error{
    case AttributesInSchemaAndInConfigurationAreDifferent
    case NodeNotFoundInTaxonomy(node:String)
}


struct ModifiedLBAAlgorithm{
    let prefs:DNF
    let schema:Schema
    let configAlg:ConfigResultAlgorithm
    
    public init(preferences:Preferences,schema:Schema,configAlg:ConfigResultAlgorithm) throws{
        if Set<Attribute>(schema.attributes) != Set<Attribute>(configAlg.attrToTaxType.keys){
            throw ModifiedLBAAlgorithmError.AttributesInSchemaAndInConfigurationAreDifferent
        }
        self.prefs = FormulaCleaner.cleanFormula(preferences: preferences)
        self.schema = schema
        self.configAlg = configAlg
    }
    
    public func getPreferredTuples() throws -> [TuplesResult]{
        let gerarchyBetweenNodes = try self.getGerarchyBetweenFormulaNodes()
        var helper = try CartesianProductHelper.init(oldGerarchy: gerarchyBetweenNodes)
        let preQueryGerarchy = try helper.getCartesianProductGerarchy()
        let tuplesGerarchy = try self.buildTuplesGerarchy(gerarchy: preQueryGerarchy)
        return try self.promoteTuples(gerarchy: tuplesGerarchy)
    }
    
    private func promoteTuples(gerarchy:Gerarchy<TuplesResult,LevelledGerarchyElement<TuplesResult>>) throws -> [TuplesResult]{
        
        var result:[Set<TuplesResult>] = []
        let lastLevel = gerarchy.getHighestLevel()
        var actualLevel = 0
        
        while actualLevel <= lastLevel {
            var actualLevelNodes = Set<TuplesResult>(gerarchy.getNodesWithLevelnth(levelnth: actualLevel).filter({!$0.node.tuples.isEmpty}).map({$0.node}))
            self.removeAlreadyInSeq(seq: result, actual: &actualLevelNodes)
            var promotedNodes = Set<TuplesResult>()
            var secondaryActualLevel = actualLevel + 1
            while secondaryActualLevel <= lastLevel{
                var tmpActual = Set<TuplesResult>(gerarchy.getNodesWithLevelnth(levelnth: secondaryActualLevel).filter({!$0.node.tuples.isEmpty}).map({$0.node}))
                self.removeAlreadyInSeq(seq: result, actual: &tmpActual)
                for node in tmpActual{
                    if try toPromote(node:node,nodeLevel:secondaryActualLevel,level:actualLevel,gerarchy:gerarchy){
                        promotedNodes.insert(node)
                    }
                }
                secondaryActualLevel += 1
            }
            result.append(actualLevelNodes.union(promotedNodes))
            actualLevel += 1
        }
        
        return result.flatMap({$0})
    }
    
    private func toPromote(node:TuplesResult,nodeLevel:Int,level:Int,gerarchy:Gerarchy<TuplesResult,LevelledGerarchyElement<TuplesResult>>) throws -> Bool {
        let id = gerarchy.valueToId(value: try LevelledGerarchyElement.init(node: node, level: nodeLevel))
        let above = gerarchy.valuesAbove[id]!
        let aboveVal = gerarchy.getMappedNodes(ids: above)
        
        for val in aboveVal{
            if val.getLevel() < level {
                continue
            }
            if !val.node.tuples.isEmpty{
                return false
            }
        }
        
        return true
    }
    
    private func removeAlreadyInSeq(seq:[Set<TuplesResult>], actual: inout Set<TuplesResult>){
        for node in actual{
            if !seq.filter({$0.contains(node)}).isEmpty {
                actual.remove(node)
            }
        }
    }
    
    private func buildTuplesGerarchy(gerarchy:Gerarchy<PreQueryNode,LevelledGerarchyElement<PreQueryNode>>) throws -> Gerarchy<TuplesResult,LevelledGerarchyElement<TuplesResult>>{
        var newIdMapping:[Int:LevelledGerarchyElement<TuplesResult>] = [:]
        let nodeValuesMapping = try self.mapNodes(gerarchy: gerarchy)
        for (id,gerarchyNode) in gerarchy.IdToActualNodeMapping{
            let mappedValues = gerarchyNode.getNode().values.map({nodeValuesMapping[$0]!})
            let mappedPreQuery = try PreQueryNode.init(values: Set<NodeValue>(mappedValues))
            newIdMapping[id] = try LevelledGerarchyElement.init(node: try self.configAlg.getTuples(queryNodes: mappedPreQuery), level: gerarchyNode.getLevel())
        }
        return Gerarchy<TuplesResult,LevelledGerarchyElement<TuplesResult>>.init(nodes: gerarchy.nodes, valuesAbove: gerarchy.valuesAbove, valuesBelow: gerarchy.valuesBelow, valuesDirectlyBelow: gerarchy.valuesDirectlyBelow, idMapping: newIdMapping)
    }
    
    private func mapNodes(gerarchy:Gerarchy<PreQueryNode,LevelledGerarchyElement<PreQueryNode>>) throws -> [NodeValue:NodeValue]{
        var result:[NodeValue:NodeValue] = [:]
        for node in gerarchy.IdToActualNodeMapping.values.map({$0.getNode()}){
            for nodeValue in node.values{
                if result[nodeValue] == nil{
                    result[nodeValue] = try self.substituteStaticValues(node: nodeValue)
                }
            }
        }
        return result
    }
    
    private func substituteStaticValues(node:NodeValue) throws -> NodeValue{
        var res = Set<Value>()
        if self.configAlg.attrToTaxType[node.attribute]! == RuleBasedConfigTax.self{
            for value in node.value{
                if !self.configAlg.ruledAttributes[node.attribute]!.rules.map({$0.value}).contains(value.name){
                    res.insert(value)
                }else{
                    res = res.union(try configAlg.getDinamic(staticNode: value, attribute: node.attribute))
                }
            }

        }else if self.configAlg.attrToTaxType[node.attribute]! == EmptyConfigTax.self {
            for value in node.value{
                res.insert(value)
            }
        }else if self.configAlg.attrToTaxType[node.attribute]! == QueryBasedConfigTax.self{
            for value in node.value{
                if try self.configAlg.isDinamic(node: value, attribute: node.attribute) {
                    res.insert(value)
                }else{
                    var staticDescendants = Set<Value>(try self.schema.attribute2Taxonomy[node.attribute]!.descendants(value: value).filter({ try !self.configAlg.isDinamic(node: $0, attribute: node.attribute) }))
                    staticDescendants.insert(value)
                    for descendant in staticDescendants{
                        res = res.union(try self.configAlg.getDinamic(staticNode: descendant, attribute: node.attribute))
                    }
                }
            }
        }
        
        return NodeValue.init(value: res, attribute: node.attribute)
    }
    
    private func getGerarchyBetweenFormulaNodes() throws -> Gerarchy<PreQueryNode,LevelledGerarchyElement<PreQueryNode>>{
        let clauses = self.prefs.clauses
        var relations:[HigherThanRelation<PreQueryNode>] = []
        for clause in clauses{
            let xLiterals = clause.literals.filter(){$0.variable == .lhs}
            let yLiterals = clause.literals.filter(){$0.variable == .rhs}
            let xNodes = Set<NodeValue>(xLiterals.map({NodeValue.init(value: Set<Value>([$0.constant]), attribute: $0.attribute)}))
            let yNodes = Set<NodeValue>(yLiterals.map({NodeValue.init(value: Set<Value>([$0.constant]), attribute: $0.attribute)}))

            let xNode:PreQueryNode
            let yNode:PreQueryNode
            do {
                xNode = try PreQueryNode.init(values: xNodes)
                yNode = try PreQueryNode.init(values: yNodes)
                relations.append(try HigherThanRelation.init(higher: xNode, lower: yNode))
            } catch {
                continue
            }
        }
        return try Gerarchy.init(relationsBetweenNodes: relations)
    }

}
   
