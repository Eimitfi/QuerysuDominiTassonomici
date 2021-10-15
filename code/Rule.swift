//
//  Rule.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 13/08/2021.
//

import Foundation

public enum MultidimensionalPointError:Error{
    case ParsingError(info:String)
    case WrongWeightOfValues(info:String)
}

public enum RuleError:Error{
    case ParsingError(info:String)
    case DifferentRulesLengthError(rules:String)
    case DifferentRulePointLengthError(differentLengthElements:String)
    case DipendentIntervalInitializationOfIndipendentInterval(interval:String)
}

enum MultidimensionalIntervalError:Error{
    case DifferentIntervalsLength(intervals:String)
    case DifferentIntervalPointLength(differentLengthElements:String)
    case DifferentIntervalLimitsLength(intervals:String)
    case WrongIntervalInclusionType(info:String)
}



public struct MultidimensionalPointParser{
    let startSeparator:String
    let endSeparator:String
    let separatorsBetweenValues:[String]
    let weightOfValues:[Int]
    
    private func checkWeightOfValues(weights:[Int]) throws {
        if weights.count == 0 {
            throw MultidimensionalPointError.WrongWeightOfValues(info: "no weights have been given")
        }
        var index = 1
        for _ in weights{
            if nil == weights.firstIndex(of: index){
                throw MultidimensionalPointError.WrongWeightOfValues(info: "the value" + String(index) + "is missing")
            }
            index += 1
        }
    }
    
    public init(separatorsBetweenValues:[String],weightOfValues:[Int],startSeparator:String = "",endSeparator:String = "") throws{
        self.startSeparator = startSeparator
        self.endSeparator = endSeparator
        self.separatorsBetweenValues = separatorsBetweenValues
        self.weightOfValues = weightOfValues
        try checkWeightOfValues(weights: weightOfValues)
    }
    private func parseStart(value:String) -> String{
        if self.startSeparator == "" {
            return value
        }
        var res:String = ""
        let tmpValue:[String] = value.components(separatedBy: self.startSeparator)
        for (i,part) in tmpValue.enumerated(){
            if i == 0 {
                continue
            }else if i > 1{
                res += self.startSeparator
            }
            res += part
        }
        return res
    }
    
    private func parseEnd(value:String) -> String{
        if self.endSeparator == "" {
            return value
        }
        var res:String = ""
        let tmpValue:[String] = value.components(separatedBy: self.endSeparator)
        for (i,part) in tmpValue.enumerated(){
            if i == (tmpValue.count - 1) {
                continue
            }
            res += part
            if i < (tmpValue.count - 2){
                res += self.endSeparator
            }
        }
        return res
    }
    
    private func parseBetween(value:String,separator:String) throws -> Point{
        if let res = Double.init(value.components(separatedBy: separator)[0]){
            return res
        }
        throw MultidimensionalPointError.ParsingError(info: value.components(separatedBy: separator)[0] + "cannot be parsed as numeric value")
    }
    
    private func updateValue(value:String,separator:String) -> String{
        let tmpValue:[String] = value.components(separatedBy: separator)
        var res = ""
        for (i,part) in tmpValue.enumerated(){
            if i == 0 {
                continue
            }
            if  i > 1 {
                res += separator
            }
            res += part
        }
        return res
    }
    
    private func order(point:MultidimensionalPoint,weights:[Int]) -> MultidimensionalPoint{
        var res:MultidimensionalPoint = []
        var index = 1
        for _ in point{
            res.append(point[weights.firstIndex(of: index)!])
            index += 1
        }
        return res
    }
    
    func parse(value:String) throws -> MultidimensionalPoint{
        var tmpValue:String
        tmpValue = self.parseEnd(value: self.parseStart(value: value))
        var res:MultidimensionalPoint = []
        for separator in self.separatorsBetweenValues{
            res.append(try parseBetween(value: tmpValue, separator: separator))
            tmpValue = updateValue(value: tmpValue,separator:separator)
        }
        res.append(try parseBetween(value: tmpValue, separator: ""))
        return self.order(point: res, weights: self.weightOfValues)
    }
}


public struct Rule{
    let value:String
    private var intervals:[MultidimensionalInterval] = []
    //costruttore per intervalli indipendenti
    public init(value:String,upperLimits u:[Double],lowerLimits d:[Double],inclusions incl:[IntervalInclusion]) throws{
        if(u.count != d.count || d.count != incl.count){
            throw MultidimensionalIntervalError.DifferentIntervalLimitsLength(intervals: "upper limits: \(u) lower limits: \(d)")
        }
        self.value = value
        self.intervals.append(try MultidimensionalInterval.init(upperLimits: u, lowerLimits: d, incl: incl))
        self.intervals.sort(by: {$0.description > $1.description})
    }
    
    public func getDim() -> Int{
        return self.intervals[0].getDim()
    }
    
    public func areIntersecating(other:Rule) throws -> Bool{
        if self.getDim() != other.getDim(){
            throw RuleError.DifferentRulesLengthError(rules: "\(self) \(other)")
        }
        var intersect = false
        for myInterval in self.intervals{
            for otherInterval in other.intervals{
                let tmpRes:Bool = try myInterval.areIntersecating(other: otherInterval)
                intersect = intersect || tmpRes
            }
        }
        return intersect
    }
    
    public func isContained(points:[Double]) throws ->Bool{
        if self.getDim() != points.count{
            throw RuleError.DifferentRulePointLengthError(differentLengthElements: "rule: \(self) point: \(points)")
        }
        var contained:Bool = false
        for interval in self.intervals{
            let tmpRes:Bool = try interval.isContained(points: points)
            contained = contained || tmpRes
        }
        return contained
    }
}

extension Rule{
    private class DipendentIntervalsInitializerHelper{
        var index:Int
        let intervals:[SimpleInterval]
        let lastInclusion:IntervalInclusion
        init(up:[Double],down:[Double],inclusion:IntervalInclusion){
            self.index = 0
            var tmpInterval:[SimpleInterval] = []
            self.lastInclusion = inclusion
            for (i,_) in up.enumerated(){
                tmpInterval.append(SimpleInterval.init(upperLimit: up[i], lowerLimit: down[i]))
            }
            self.intervals = tmpInterval
        }
        func getInternalIntervals() -> [SimpleInterval]{
            return self.intervals
        }
        func getBeforeIntervals() -> [SimpleInterval]{
            var ints:[SimpleInterval] = []
            for (i,interval) in self.intervals.enumerated(){
                if i >= self.index{
                    break
                }
                ints.append(interval)
            }
            return ints
        }
        func isDisjoint() -> Bool {
            let actual = self.getActualNoInclusion()
            return actual.lowerLimit > actual.upperLimit
        }
        private func getActualNoInclusion() -> SimpleInterval{
            return self.intervals[index]
        }
        func afterHasDontCare() -> Bool{
            var everyoneAfterIsDontCare = true
            if self.isLast(){
                return false
            }
            for (i,interval) in self.intervals.enumerated(){
                if i <= self.index{
                    continue
                }
                everyoneAfterIsDontCare = everyoneAfterIsDontCare && interval.isDontCare()
            }
            return everyoneAfterIsDontCare
        }
        func getActualInclusion() -> IntervalInclusion{
            if self.isLast() || self.afterHasDontCare(){
                return self.lastInclusion
            }else{
                return IntervalInclusion.init(up: Inclusion.Excluded, down: Inclusion.Excluded)
            }
        }
        func getBeforeActual() -> [[SimpleInterval]]{
            var res:[[SimpleInterval]] = []
            let beforeActualInterval = self.getBeforeIntervals()
            if (!self.isFirst() && !self.beforeHasOnlyEqualOrDontCare()){
                res.append([])
                res.append([])
                for interval in beforeActualInterval{
                    if interval.isDontCare(){
                        res[0].append(interval)
                        res[1].append(interval)
                    }else{
                        res[0].append(SimpleInterval.init(upperLimit: interval.lowerLimit, lowerLimit: interval.lowerLimit))
                        res[1].append(SimpleInterval.init(upperLimit: interval.upperLimit, lowerLimit: interval.upperLimit))
                    }

                }
            }else{
                res.append(beforeActualInterval)
                if self.isDisjoint(){
                    res.append(beforeActualInterval)
                }
            }
            return res
        }
        func getActual() -> [SimpleInterval]{
            var res:[SimpleInterval] = []
            let actual = self.getActualNoInclusion()
            let incl = self.getActualInclusion()
            if (self.isFirst() || self.beforeHasOnlyEqualOrDontCare()) && !self.isDisjoint(){
                    res.append(SimpleInterval.init(upperLimit: actual.upperLimit, lowerLimit: actual.lowerLimit, inclusion: incl))
            }else{
                res.append(SimpleInterval.init(upperLimit: Point.infinity, lowerLimit: actual.lowerLimit, inclusion: IntervalInclusion.init(up: Inclusion.Excluded, down: incl.lowerInclusion)))
                
                res.append(SimpleInterval.init(upperLimit: actual.upperLimit, lowerLimit: -Point.infinity, inclusion: IntervalInclusion.init(up: incl.upperInclusion, down: Inclusion.Excluded)))
            }
            return res
        }
        func intervalInRound() -> Bool{
            return !((self.isEqual(i: self.index) && !self.isLast()) || self.isDontCare(i: self.index))
        }
        func beforeHasOnlyEqualOrDontCare() -> Bool{
            if self.isFirst(){
                return false
            }
            var everyoneIsEqualOrDontCare = true
            for (i,_) in self.intervals.enumerated(){
                if i >= self.index{
                    break
                }
                let isEqualOrDontCare = self.isEqual(i: i) || self.isDontCare(i: i)
                everyoneIsEqualOrDontCare = everyoneIsEqualOrDontCare && isEqualOrDontCare
            }
            return everyoneIsEqualOrDontCare
        }
        func createDontCare() -> SimpleInterval{
            return SimpleInterval.init(upperLimit: Point.infinity, lowerLimit: -Point.infinity)
        }
        func getAfterActual() -> [SimpleInterval]{
            var ints:[SimpleInterval] = []
            for (i,_) in self.intervals.enumerated(){
                if i <= self.index{
                    continue
                }
                ints.append(self.createDontCare())
            }
            return ints
        }
        func isLast() -> Bool{
            return self.index == (self.getDim() - 1)
        }
        func isEqual(i:Int) -> Bool{
            return intervals[i].upperLimit == intervals[i].lowerLimit
        }
        func isDontCare(i:Int) -> Bool{
            return (intervals[i].upperLimit == Double.infinity && intervals[i].lowerLimit == -Double.infinity) || (intervals[i].upperLimit == -Double.infinity && intervals[i].lowerLimit == Double.infinity)
        }

        private func isFirst() -> Bool {
            return self.index == 0
        }
        private func getDim() -> Int{
            return self.intervals.count
        }
        public func processIsFinished() -> Bool{
            return self.index == self.getDim()
        }
        public func nextRound(){
            self.index = self.index + 1
        }
       public func getCurrentRoundMultidimensionalIntervals() -> [MultidimensionalInterval]{
            var res:[MultidimensionalInterval] = []
            var interval:[[SimpleInterval]] = []
            let afterActual = self.getAfterActual()
            let actual:[SimpleInterval] = self.getActual()
            let beforeActual:[[SimpleInterval]] = self.getBeforeActual()
            if (self.isFirst() || self.beforeHasOnlyEqualOrDontCare()) && !self.isDisjoint(){
                interval.append([])
                interval[0].append(contentsOf: beforeActual[0])
                interval[0].append(actual[0])
                interval[0].append(contentsOf: afterActual)
            }else{
                interval.append([])
                interval.append([])
                interval[0].append(contentsOf: beforeActual[0])
                interval[1].append(contentsOf: beforeActual[1])
                interval[0].append(actual[0])
                interval[1].append(actual[1])
                interval[0].append(contentsOf: afterActual)
                interval[1].append(contentsOf: afterActual)
            }
            
            for elem in interval{
                res.append(MultidimensionalInterval.init(intervals: elem))
            }

            return res
        }
        func isAlreadyNormalized() -> Bool{
            let saveIndex = self.index
            self.index = self.getDim()
            let isAlreadyNormalized = self.beforeHasOnlyEqualOrDontCare()
            self.index = saveIndex
            return isAlreadyNormalized
        }
    }
    
    public init(value:String,upperLimits u:[Double],lowerLimits d:[Double],inclusion incl:IntervalInclusion) throws{
        var ints:[MultidimensionalInterval] = []
        if u.count != d.count{
            throw MultidimensionalIntervalError.DifferentIntervalLimitsLength(intervals: "upper limits: \(u) lower limits: \(d)")
        }
        if u.count == 1{
            throw RuleError.DipendentIntervalInitializationOfIndipendentInterval(interval: "upper limit: \(u) lowerLimit:\(d), must be initialized using the indipendent interval initializator")
        }
        self.value = value
        let stateHolder = Rule.DipendentIntervalsInitializerHelper.init(up: u, down: d, inclusion: incl)
        
        if stateHolder.isAlreadyNormalized(){
            ints.append(MultidimensionalInterval.init(intervals:  stateHolder.getInternalIntervals()))
            self.intervals = ints
            return
        }
        while(!stateHolder.processIsFinished()){
            if stateHolder.intervalInRound(){
                ints.append(contentsOf: stateHolder.getCurrentRoundMultidimensionalIntervals())
            }
            stateHolder.nextRound()
        }
        self.intervals = ints
        //motivo:
        self.intervals.sort(by: {$0.description > $1.description})
    }
}

struct MultidimensionalInterval{
    var intervals:[MonodimensionalInterval] = []
    
    init(upperLimits u:[Double],lowerLimits d:[Double], incl:[IntervalInclusion]) throws{
        if(u.count != d.count || d.count != incl.count){
            throw MultidimensionalIntervalError.DifferentIntervalsLength(intervals: "\(u) \(d)")
        }
        
        for (i,_) in u.enumerated(){
            let interval:MonodimensionalInterval
            if SimpleInterval.isDontCare(up: u[i], down: d[i]){
                interval = DontCareMonodimensionalInterval.init()
            }else{
                interval = try SpecificMonodimensionalInterval.init(upperLimit: u[i], lowerLimit: d[i], inclusion: incl[i])
            }
            self.intervals.append(interval)
        }
        
    }
    
    func getDim()-> Int{
        return self.intervals.count
    }
    
    func areIntersecating(other:MultidimensionalInterval) throws -> Bool{
        if other.getDim() != self.getDim(){
            throw MultidimensionalIntervalError.DifferentIntervalsLength(intervals: "\(self) \(other)")
        }
        var contained:Bool = true
        for (index,monoInterval) in self.intervals.enumerated(){
            contained = contained && monoInterval.areIntersecting(other: other.intervals[index])
        }
        return contained
    }
    
    func isContained(points:[Point]) throws -> Bool {
        if points.count != points.count{
            throw MultidimensionalIntervalError.DifferentIntervalPointLength(differentLengthElements: "\(self) \(points)")
        }
        var contained:Bool = true
        for (index,interval) in self.intervals.enumerated(){
            contained = contained && interval.isContained(point: points[index])
        }
        return contained
    }
}

extension MultidimensionalInterval:Hashable{
    static func == (lhs: MultidimensionalInterval, rhs: MultidimensionalInterval) -> Bool {
        return lhs.description == rhs.description
    }
    public func hash(into hasher: inout Hasher) {
        var spec:Set<SpecificMonodimensionalInterval> = Set<SpecificMonodimensionalInterval>()
        var dont:Set<DontCareMonodimensionalInterval> = Set<DontCareMonodimensionalInterval>()
        for int in self.intervals{
            if int is SpecificMonodimensionalInterval{
                spec.insert(int as! SpecificMonodimensionalInterval)
            }else{
                dont.insert(int as! DontCareMonodimensionalInterval)
            }
        }
        hasher.combine(spec)
        hasher.combine(dont)
    }
    
    
    init(intervals:[SimpleInterval]){
        for (i,_) in intervals.enumerated(){
            let interval:MonodimensionalInterval
            if intervals[i].isDontCare(){
                interval = DontCareMonodimensionalInterval.init()
            }else{
                interval = SpecificMonodimensionalInterval.init(interval: intervals[i])
            }
            self.intervals.append(interval)
        }
    }
}

protocol MonodimensionalInterval:CustomStringConvertible {
    var description:String { get }
    func areIntersecting(other:MonodimensionalInterval) ->Bool
    func isContained(point:Point) ->Bool
}

struct DontCareMonodimensionalInterval:MonodimensionalInterval,Hashable{
    func areIntersecting(other: MonodimensionalInterval) -> Bool {
        return true
    }
    
    func isContained(point: Point) -> Bool {
        return true
    }
    
    init(){
        
    }
    
}

struct SpecificMonodimensionalInterval:MonodimensionalInterval,Hashable{
    var simpleIntervals:[SimpleInterval]
    
    init(upperLimit u:Double,lowerLimit d:Double, inclusion:IntervalInclusion) throws {
        self.simpleIntervals = [SimpleInterval.init(upperLimit: u, lowerLimit: d, inclusion: inclusion)]

        self.simpleIntervals = handleDisjointInterval(ints: self.simpleIntervals)
    }
    
    func areIntersecting(other: MonodimensionalInterval) -> Bool {
        var intersect:Bool = false
        if other is DontCareMonodimensionalInterval{
            return true
        }
        if let oth = other as? SpecificMonodimensionalInterval{
            for myInterval in self.simpleIntervals{
                for otherInterval in oth.simpleIntervals{
                    intersect = intersect || myInterval.isIntersecting(other: otherInterval)
                }
            }
        }
        
        return intersect
    }
    
    func isContained(point: Point) -> Bool {
        var contained:Bool = false
        for interval in self.simpleIntervals{
            contained = contained || interval.isContained(point: point)
        }
        return contained
    }
    
    private func handleDisjointInterval(ints:[SimpleInterval]) -> [SimpleInterval]{
        var res:[SimpleInterval] = []
        for int in ints{
            res.append(contentsOf: int.getDisjointIntervalIfPresent())
        }
        return res
    }
}

extension SpecificMonodimensionalInterval{
    init(interval:SimpleInterval){
        self.simpleIntervals = [interval]
        self.simpleIntervals = handleDisjointInterval(ints: self.simpleIntervals)
    }
}

enum SimpleIntervalError:Error{
    case LimitParsingError(parsedLimit:String)
    case InclusionParsingError(parsedInclusion:String)
}

struct SimpleInterval{
    let lowerLimit:Point
    let upperLimit:Point
    let inclusion:IntervalInclusion

    
     func getDisjointIntervalIfPresent() -> [SimpleInterval]{
        if self.lowerLimit <= self.upperLimit{
            return [self]
        }
        
        return [SimpleInterval.init(upperLimit: self.lowerLimit, lowerLimit: -Point.infinity, inclusion: IntervalInclusion.init(up: self.inclusion.lowerInclusion, down: Inclusion.Included)),SimpleInterval.init(upperLimit: Point.infinity, lowerLimit: self.upperLimit, inclusion: IntervalInclusion.init(up: Inclusion.Included, down: self.inclusion.upperInclusion))]
    }
    
     func isIntersecting(other:SimpleInterval) -> Bool{
        var res = false
        if other.inclusion.lowerInclusion == .Included{
            if isContained(point: other.lowerLimit){
                res = true
            }
        }else{
            if isContained(point: other.lowerLimit.nextUp){
                    res = true
                }
        }
            
        if other.inclusion.upperInclusion == .Included{
            if isContained(point: other.upperLimit){
                res = true
            }
        }else{
            if isContained(point: other.upperLimit.nextDown){
                    res = true
            }
        }
        return res
    }
    func isDontCare() -> Bool{
        return (self.upperLimit == Double.infinity && self.lowerLimit == -Double.infinity) || (self.upperLimit == -Double.infinity && self.lowerLimit == Double.infinity)
    }
    static func isDontCare(up:Point,down:Point) -> Bool{
        return (up == Double.infinity && down == -Double.infinity) || (up == -Double.infinity && down == Double.infinity)
    }
    
     func isContained(point:Point) -> Bool{
        var contained:Bool = true
        if self.inclusion.lowerInclusion == .Included{
            if self.lowerLimit > point {
                contained = false
            }
        }else{
            if self.lowerLimit >= point {
                contained = false
            }
        }
        
        if self.inclusion.upperInclusion == .Included{
            if self.upperLimit < point {
                contained = false
            }
        }else{
            if self.upperLimit <= point {
                contained = false
            }
        }
        return contained
    }
    
    init(upperLimit ul:Point, lowerLimit dl:Point,inclusion:IntervalInclusion){
        self.upperLimit = ul
        self.lowerLimit = dl
        self.inclusion = inclusion
    }
}
typealias MultidimensionalPoint = [Point]
typealias Point =  Double

public struct IntervalInclusion{
    let lowerInclusion:Inclusion
    let upperInclusion:Inclusion
    public init(up:Inclusion,down:Inclusion){
        self.upperInclusion = up
        self.lowerInclusion = down
    }
}

public enum Inclusion{
    case Included
    case Excluded
}


extension Rule{
    //helper nel parsing
    public init(value:String,upperLimits uL:[String],lowerLimits dL:[String],upperInclusions uI:[String],lowerInclusions dI:[String]) throws{

        if uI.count != dI.count || uL.count != dL.count{
            throw MultidimensionalIntervalError.DifferentIntervalLimitsLength(intervals: "upper : \(uL)  lower: \(dL)")
        }
        var uppL:[Double] = []
        var dowL:[Double] = []
        var incl:[IntervalInclusion] = []
        for val in uL{
            do {
                uppL.append(try SimpleInterval.limitParser(limit: val))
            }catch SimpleIntervalError.LimitParsingError{
                throw RuleError.ParsingError(info: "error in parsing limit \(val)")
            }
        }
        for val in dL{
            do{
                dowL.append(try SimpleInterval.limitParser(limit: val))
            }catch SimpleIntervalError.LimitParsingError{
                throw RuleError.ParsingError(info: "error in parsing limit \(val)")
            }
        }
        for (i,_) in uI.enumerated(){
            do{
                incl.append(try IntervalInclusion.InclusionParser(up: uI[i], down: dI[i]))
            }catch SimpleIntervalError.InclusionParsingError{
                throw RuleError.ParsingError(info: "error in parsing inclusion \(uI[i]) - \(dI[i])")
            }
        }
        if uppL.count == incl.count{
            try self.init(value: value, upperLimits: uppL, lowerLimits: dowL, inclusions: incl)
            return
        }
        if incl.count == 1 && uppL.count > 1{
            try self.init(value: value, upperLimits: uppL, lowerLimits: dowL, inclusion: incl[0])
            return
        }
        throw MultidimensionalIntervalError.WrongIntervalInclusionType(info: "interval length: \(uppL.count) inclusions length: \(incl.count)")
        
    }
}

extension Rule:CustomStringConvertible,Equatable,Hashable{
    public static func == (lhs: Rule, rhs: Rule) -> Bool {
        return lhs.description == rhs.description
    }
    
    public var description: String {return self.getDescription()}
    
    private func getDescription() -> String{
        var res = ""
        res += self.value + "\n"
        for elem in intervals{
            res += "(" + elem.description + ")\n"
        }
        return res
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.description)
    }
}

extension MultidimensionalInterval:CustomStringConvertible{
    public var description: String {return self.getDescription()}
    private func getDescription() -> String{
        var res = ""
        for (i,elem) in self.intervals.enumerated(){
            if i == (self.getDim() - 1){
                res += elem.description
            }else{
                res += elem.description + ", "

            }
        }
        return res
    }
}

extension DontCareMonodimensionalInterval:Equatable,CustomStringConvertible{
    var description: String {return "dontCare"}
}

extension SpecificMonodimensionalInterval:Equatable,CustomStringConvertible{
    var description: String {return self.getDescription()}
    private func getDescription() -> String{
        var res = ""
        for elem in self.simpleIntervals{
            res += elem.description + " "
        }
        return res
    }
}

extension SimpleInterval{
    
    //costruttore di utilita'
    init(upperLimit ul:Point, lowerLimit dl:Point){
        self.upperLimit = ul
        self.lowerLimit = dl
        self.inclusion = IntervalInclusion.init(up: Inclusion.Included, down: Inclusion.Included)
    }
    
    static func limitParser(limit:String) throws -> Point{
        if limit == "+inf" {
            return Point.infinity
        }
        if limit == "-inf" {
            return -Point.infinity
        }
        
        let parsed = Point(limit)
        guard parsed != nil else {throw SimpleIntervalError.LimitParsingError(parsedLimit: limit)}
        return parsed!
    }
    
}

extension SimpleInterval:Equatable,CustomStringConvertible,Hashable{
    var description: String {return self.inclusion.getlowerDescription() + String(self.lowerLimit) + " - " + String(self.upperLimit) + self.inclusion.getUpperDescription()}
    
    
    public static func == (lhs:SimpleInterval,rhs:SimpleInterval) -> Bool{
        return lhs.lowerLimit == rhs.lowerLimit && lhs.upperLimit == rhs.upperLimit && lhs.inclusion == rhs.inclusion
    }
    
}

extension IntervalInclusion{
    static public func InclusionParser(up:String,down:String) throws -> IntervalInclusion{
        return self.init(up: try Inclusion.inclusionParser(inclusion: up, up: true), down: try Inclusion.inclusionParser(inclusion: down, up: false))
    }
}

extension IntervalInclusion:Equatable,Hashable{
    public static func == (lhs:IntervalInclusion,rhs:IntervalInclusion) -> Bool{
        return lhs.lowerInclusion == rhs.lowerInclusion && lhs.upperInclusion == rhs.upperInclusion
    }
    
    func getlowerDescription() -> String{
        if self.lowerInclusion == .Excluded{
            return "]"
        }else{
            return "["
        }
    }
    
    func getUpperDescription() -> String{
        if self.upperInclusion == .Excluded{
            return "["
        }else{
            return "]"
        }
    }
}

extension Inclusion:Hashable{
    static func inclusionParser(inclusion:String,up:Bool) throws -> Inclusion{
       if inclusion != "[" && inclusion != "]" {
        throw SimpleIntervalError.InclusionParsingError(parsedInclusion: inclusion)
       }
       var res:Inclusion = Inclusion.Excluded
       if up {
           if inclusion == "[" {
               res = Inclusion.Excluded
           }else{
               res = Inclusion.Included
           }
       }
       
       if !up {
           if inclusion == "[" {
               res = Inclusion.Included
           }else{
               res = Inclusion.Excluded
           }
       }
       return res
   }
}
