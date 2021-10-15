//
//  ResultAlgorithmUtility.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 18/09/2021.
//

import Foundation


struct CartesianProductHelper{
    let oldGerarchy:Gerarchy<PreQueryNode,LevelledGerarchyElement<PreQueryNode>>
    var newNodes:Set<LevelledGerarchyElement<PreQueryNode>>
    
    init(oldGerarchy:Gerarchy<PreQueryNode,LevelledGerarchyElement<PreQueryNode>>)throws{
        self.newNodes = Set<LevelledGerarchyElement<PreQueryNode>>()
        self.oldGerarchy = oldGerarchy
    }
    
    private func cloneNode(node:LevelledGerarchyElement<PreQueryNode>) throws -> LevelledGerarchyElement<PreQueryNode>{
        return try LevelledGerarchyElement<PreQueryNode>.init(node: PreQueryNode.init(values: node.getNode().values), level: node.getLevel())
    }
    
    mutating func getCartesianProductGerarchy() throws -> Gerarchy<PreQueryNode,LevelledGerarchyElement<PreQueryNode>>{
        var relations:[LevelledHigherThanRelation<PreQueryNode,LevelledGerarchyElement<PreQueryNode>>] = []
        for node in oldGerarchy.IdToActualNodeMapping.values{
            let actualNode = try self.cloneNode(node: node)
            try self.addNodeRecurs(node: actualNode)
        }
        
        for node in self.newNodes{
            let downerNodes = self.newNodes.filter({$0.node.haveAtLeastACommonValue(other: node.node) && $0.getLevel() > node.getLevel()})
            for downNode in downerNodes{
                relations.append(try LevelledHigherThanRelation<PreQueryNode,LevelledGerarchyElement<PreQueryNode>>.init(higher: node, lower: downNode))
            }
        }
        if relations.isEmpty{
            return self.oldGerarchy
        }
        return Gerarchy.init(relationsBetweenNodes: relations)
    }
    
    private mutating func addNodeRecurs(node:LevelledGerarchyElement<PreQueryNode>) throws{
        let compatibleNodes = oldGerarchy.IdToActualNodeMapping.values.filter({$0.getNode().nodeIsCompatible(other: node.getNode())})
        if compatibleNodes.isEmpty{
            newNodes.insert(node)
        }else{
            for compatibleNode in compatibleNodes{
                let newNode = try PreQueryNode.mergeNodes(node1: node.getNode(), node2: compatibleNode.getNode())
                let newElement = try LevelledGerarchyElement<PreQueryNode>.init(node: newNode, level: node.getLevel() + compatibleNode.getLevel())
                try self.addNodeRecurs(node: newElement)
            }
        }
    }
}

//struct per rendere piu semplice l'aggiunta/rimozione di logica per pulire la formula in input
struct FormulaCleaner{
    
    private static func cleanFormula(name:String,clauses:[Clause]) -> DNF{
        var newClauses = clauses
        newClauses = FormulaCleaner.cleanSameValue(clauses: newClauses)
        return DNF.init(name: name, clauses: newClauses)
    }
    
    static func cleanFormula(preferences:Preferences) -> DNF{
        var clauses:[Clause] = []
        for formula in preferences.preferences{
            clauses.append(contentsOf: formula.clauses)
        }
        return FormulaCleaner.cleanFormula(name: "cleanedFormula", clauses: clauses)
    }
    
    static func cleanFormula(formula:DNF) -> DNF {
        return FormulaCleaner.cleanFormula(name:formula.name, clauses: formula.clauses)
    }
    static private func cleanSameValue(clauses:[Clause]) -> [Clause]{
        var newClauses:[Clause] = []
        
        for clause in clauses{
            var sameValue = true
            let xLiterals = clause.literals.filter(){$0.variable == .lhs}
            let yLiterals = clause.literals.filter(){$0.variable == .rhs}
            
            for literal in xLiterals{
                if !sameValue {break}
                if yLiterals.filter({$0.constant == literal.constant && $0.attribute == literal.attribute}).isEmpty{
                    sameValue = false
                }
            }
            for literal in yLiterals{
                if !sameValue {break}
                if xLiterals.filter({$0.constant == literal.constant && $0.attribute == literal.attribute}).isEmpty{
                    sameValue = false
                }
            }
            if !sameValue{
                newClauses.append(clause)
            }
        }
        
        return newClauses
    }
}


