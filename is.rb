#!/usr/bin/env ruby
# -*- coding:utf-8 -*-

require './rdparse.rb'
require './isLib.rb'

class IS
    def initialize
        @IS = Parser.new("Idiotsäkert") do
            @commands = Prog.new()

            token(/\s+/)                                    #Garbage/White space
            token(/\/\/(.+)/)                               #Comments
            token(/^(sf|nmr|str)/) {|m| m }                 #Var types
            token(/-?[0-9]+(\.[0-9]+)/) {|m| m.to_f }       #Floats
            token(/-?\d+/) {|m| m.to_i }                    #Integers
            token(/"(.+)"/){|m| m}                          #Strings
            token(/""/){|m| m}                              #Empty strings
            token(/(\w+|[åÅäÄöÖ])+/) {|m| m }               #Strings
            token(/(&&|>=|<=|\|\||!=|==)/) {|m| m }         #Comp Operators
            token(/./) {|m| m }                             #Characters

            start :program do
                match(:cmds) {|m| @commands << m; @commands}
            end
            

            rule :cmds do
                match(:funcdec, :cmds) {|vl, hl| [vl] + [hl]}
                match(:stmts)
                match(:funcdec)
            end

            rule :stmts do
                match(:stmts, :stmt) {|vl, hl| [vl] + [hl]}
                match(:stmt)
            end

            rule :stmt do
                match(:annars)
                match(:alternativt)
                match(:om)
                match(:kor)
                match(:medan)
                match(:IO, :eol) {|io| io}
                match(:vardec, :eol) {|vdec| vdec}
                match(:change_var, :eol) {|cvar| cvar}
                match(:func, :eol) {|fcall| fcall}
            end

            rule :IO do
                match(:out)
                match(:in)
            end

            rule :out do
                match('ut', '(', String, ')') {|_,_, t| Print.new(t) }
                match('ut', '(', '"', '"', ')') { Print.new("") }
                match('ut', '(' , ')') { Print.new() }
            end

            rule :in do
                match('in', '(', String, ')') {|_,_, t| Input.new(t)}
                match('in', '(', '"', '"', ')') { Input.new("") }
                match('in', '(', ')') { Input.new() }
            end

            rule :vardec do 
                match(:boolexprdec)
                match(:nmrdec)
                match(:strdec)
            end

            rule :change_var do
                match(String, '=', :in) {|name,_, value| Change_var.new(name, value)}
                match(String, '=', :var) {|name,_, value| Change_var.new(name, value)}
            end

            rule :om do 
                match('om', '(', :villkor, ')', '{', :stmts, '}') {|_,_, cond,_,_, stmts| If.new(cond, stmts)}
            end

            rule :alternativt do
                match(:alternativt, 'alternativt', '(', :villkor, ')', '{', :stmts, '}'){
                    |stmt_obj,_,_, cond, _,_, elif_stmts|
                    If_Elif.new(stmt_obj, cond, elif_stmts)
                }
                match(:om, 'alternativt', '(', :villkor, ')', '{', :stmts, '}') {
                    |stmt_obj,_,_, cond, _,_, elif_stmts|
                    If_Elif.new(stmt_obj, cond, elif_stmts)
                }
            end

            rule :annars do
                match(:alternativt, 'annars', '{', :stmts, '}') {
                    |stmt_obj, _,_, else_stmts|
                    If_Else.new(stmt_obj, else_stmts)
                }

                match(:om, 'annars', '{', :stmts, '}') {
                    |stmt_obj,_,_, else_stmts|
                    If_Else.new(stmt_obj, else_stmts)
                }
            end

            rule :kor do
                match('kör', '(', :nums, ')', 'som', '(', String, ')', '{', :stmts, '}'){
                    |_,_, times,_,_,_, variable,_,_, stmts|
                    For.new(times, stmts, variable)
                }
                match('kör', '(', :nums, ')', '{', :stmts, '}'){
                    |_,_, times,_,_, stmts|
                    For.new(times, stmts)
                }
            end

            rule :medan do
                match('medan', '(', :villkor, ')', '{', :stmts, '}'){
                    |_,_, cond,_,_, stmts|
                    While.new(cond, stmts)
                }
            end

            rule :nmrdec do
                match('nmr', String, '=', :nums) {|type, name, _,nmr| Var.new(type, name, nmr)}
            end

            rule :strdec do
                match('str', String, '=', :in) {|type, name, _, str| Var.new(type, name, str)}
                match('str', String, '=', String) {|type, name, _, str| Var.new(type, name, str)}
            end

            rule :sfdec do
                match('sf', String, '=', :boolexpr) {|type, name, _, sf| Var.new(type, name, sf)}
            end

            rule :boolexpr do
                match(:var, :compop, :var){|vl, op, hl| BoolExpr.new(vl, op, hl)}
                match(:sf)
            end

            rule :sf do
                match('sant') {|b| Boolean.new("True")}
                match('falskt') {|b| Boolean.new("False")}
            end

            rule :var do
                match(:var, '+', :boolexpr) {|vl,_,hl| VarExpr.new(vl, hl) }
                match(:var, '+', String) {|vl,_,hl| VarExpr.new(vl, hl) }
                match(:var, '+', :nums) {|vl,_,hl| VarExpr.new(vl, hl) }
                match(:sf)
                match(String)
                match(:nums)
            end

            rule :nums do
                match(Integer, :math_op, :nums) {|vl, op, hl| Mathop.new(vl, op, hl)}
                match(Float, :math_op, :nums) {|vl, op, hl| Mathop.new(vl, op, hl)}
                match(Integer)
                match(Float)
            end

            rule :math_op do
                match('+')
                match('-')
                match('*')
                match('/')
            end

            rule :villkor do
                match(:villkor, :op, :villkor) {|vl, op, hl| Cond.new(vl, op, hl)}
                match(:var)
            end

            rule :op do
                match(:logicop)
                match(:compop)
            end

            rule :logicop do
                match('&&')
                match('och') {||' and '}
                match('||')
                match('eller') {||' or '}
                match('!')
                match(:logicop, 'inte') {|vl| vl + 'not '}
            end

            rule :compop do
                match('==')
                match('!=')
                match('<')
                match('>')
                match('<=')
                match('>=')
            end

            rule :funcdec do
                match('funktion', String, '(', ')', '{', :stmts, 'retur', :var, :eol, '}'){
                    |_, name,_,_,_,stmts,_,rvar|
                    Func.new(name, stmts, rvar)
                }
                match('funktion', String, '(', :funcvar, ')', '{', :stmts, 'retur', :var, :eol, '}'){
                    |_, name,_,fvar,_,_,stmts,_,rvar|
                    Func.new(name, stmts, rvar, fvar)
                }
            end

            rule :funcvar do
                match(:v_types, String, ',', :funcvar) {|_,vl,_, hl| ([vl] + [hl]).flatten}
                match(:funcvar, ',', :vardec) {|vl,_, hl| ([vl] + [hl]).flatten}
                match(:vardec)
                match(:v_types, String){|_,hl| [hl]}
            end

            rule :v_types do
                match('str')
                match('nmr')
                match('sf')
            end

            rule :func do
                match(String, '(', :f_args, ')'){
                    |name,_,vars| 
                    Funccall.new(name, vars)
                }

                match(String, '(', ')'){
                    |name|
                    Funccall.new(name)
                }
            end

            rule :f_args do
                match(:var, ',', :f_args) {|vl,_, hl| ([vl] + [hl]).flatten}
                match(:func, ',', :f_args) {|vl,_, hl| ([vl] + [hl]).flatten}
                match(:func) {|v| [v]}
                match(:var)  {|v| [v]}
            end

            rule :eol do
                match(';')
            end

        end
    end
  
    def done(str)
        ["quit","exit","bye",""].include?(str.chomp)
    end
  
    def command(sourceFile, destFile)
        if(sourceFile[-3,3]!=".is")
            sourceFile = sourceFile + ".is"
        end
        if(destFile[-3,3]!=".py")
            destFile = destFile + ".py"
        end
        
        lines = IO.readlines(sourceFile).join

        open(destFile, 'w') { |f|
            f.puts "#!/usr/bin/env/python3\n# -*- coding: utf-8 -*-"
            f.puts @IS.parse(lines).compile #shits on fire yo
        }
    end

    def log(state = true)
        if state
            @IS.logger.level = Logger::DEBUG
        else
            @IS.logger.level = Logger::WARN
        end
    end
end


is = IS.new
#is.log(false)
is.command(ARGV[0], ARGV[1])
