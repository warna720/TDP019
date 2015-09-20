#!/usr/bin/env ruby
# -*- coding:utf-8 -*-

class Prog
    def initialize
        @cmds = []
    end

    def <<(cmd)
        if cmd.kind_of?(Array)
            @cmds.concat(cmd.flatten)
        else
            @cmds << cmd
        end
    end

    def compile(subcomp = nil)
        result = []
        @cmds.each do |cmd|
            result << cmd.compile
        end
        result
    end
end

class General

    def compile_stmts(stmts, indent = "")

        if stmts.kind_of?(Array)
            stmts = stmts.flatten
            result = ""
            stmts.each do |stmt|
                result += stmt.compile(indent) + "\n"
            end
            stmts = result
        else
            stmts = stmts.compile(indent)
        end

        stmts
    end
end

class Print < General

    def initialize(out = nil)
        @out = out
    end

    def compile(indent = "")
        if @out
            indent + "print(" + @out + ")"
        else
            indent + "print()"
        end
    end
end

class Input < General
    def initialize(inp = nil)
        @inp = inp
    end

    def compile(indent = "")
        if @inp
            return indent + "input(" + @inp + ")"
        else
            return indent + "input()"
        end
    end
end

class Var < General

    def initialize(type, name, value)
        @type = type
        @name = name
        @value = value
    end

    def compile(indent = "")
        if @type == "str" and not @value.kind_of?(Input)
            @value.gsub!(/^"/, "")
            @value.gsub!(/"$/, "")
            @value = "\"" + @value + "\""
        end

        if @value.kind_of?(Mathop)
            @value = @value.compile(indent)
        elsif @value.kind_of?(Input)
            @value = @value.compile(indent)
        elsif @value.kind_of?(BoolExpr)
            @value = @value.compile(indent)
        end

        if not DeclaredVars.is_declared(@name)
            DeclaredVars.declare(@name, @type)
        else
            #debug message
            #puts "Variable " + @name + " already declared."
        end

        indent + @name + " = " + @value.to_s
    end
end

class VarExpr < General

    def initialize(vl, hl)
        @vl = vl
        @hl = hl
    end

    def compile(indent = "")

        if @vl.kind_of?(Mathop) or @vl.kind_of?(VarExpr)
            @vl = @vl.compile(indent)
        end
        if @hl.kind_of?(Mathop) or @hl.kind_of?(VarExpr)
            @hl = @hl.compile(indent)
        end

        indent + @vl.to_s + " + " + @hl.to_s
    end
end

class Boolean < General

    def initialize(boolean)
        @boolean = boolean
    end

    def compile(indent = "")
        @boolean
    end
end

class BoolExpr < General

    def initialize(vl, op, hl)
        @vl = vl
        @op = op
        @hl = hl
    end

    def compile(indent = "")

        if @vl.kind_of?(Mathop) or @vl.kind_of?(VarExpr) or @vl.kind_of?(Boolean)
            @vl = @vl.compile(indent)
        end
        if @hl.kind_of?(Mathop) or @hl.kind_of?(VarExpr) or @hl.kind_of?(Boolean)
            @hl = @hl.compile(indent)
        end

        indent + @vl.to_s + @op.to_s + @hl.to_s
    end
end


class If < General

    def initialize(cond, stmts)
        @cond = cond
        @stmts = stmts
    end

    def compile(indent = "")
        @stmts = compile_stmts(@stmts, indent + "\t")
        indent + "if(" + @cond.compile + "):\n" + @stmts
    end
end

class If_Elif < General

    def initialize(stmt_obj, cond, elif_stmts)
        @stmt_obj = stmt_obj
        @cond = cond
        @elif_stmts = elif_stmts
    end

    def compile(indent = "")
        @elif_stmts = compile_stmts(@elif_stmts, indent + "\t")
        @stmt_obj.compile(indent) + "\n\n" + indent + "elif(" + @cond.compile + "):\n" + @elif_stmts
    end
end

class If_Else < General

    def initialize(stmt_obj, else_stmts)
        @stmt_obj = stmt_obj
        @else_stmts = else_stmts
    end

    def compile(indent = "")
        @else_stmts = compile_stmts(@else_stmts, indent + "\t")
        @stmt_obj.compile(indent) + "\n" + indent + "else:\n" + @else_stmts
    end
end

class Cond < General

    def initialize(vl, op, hl)
        @vl = vl
        @op = op
        @hl = hl
    end

    def compile
        if @vl.kind_of?(Cond) or @vl.kind_of?(Mathop) or @vl.kind_of?(VarExpr)
            @vl = @vl.compile
        end

        if @hl.kind_of?(Cond) or @hl.kind_of?(Mathop) or @hl.kind_of?(VarExpr)
            @hl = @hl.compile
        end

        @vl.to_s + @op.to_s + @hl.to_s
    end
end

class For < General
    def initialize(times, stmts, variable = "i")
        @times = times
        @stmts = stmts
        @variable = variable
    end

    def compile(indent = "")
        @stmts = compile_stmts(@stmts, indent + "\t")

        if @times.kind_of?(Mathop)
            @times = @times.compile
        end

        "for " + @variable + " in range(" + @times.to_s + "):\n" + indent + @stmts 
    end
end

class While < General
    def initialize(cond, stmts)
        @cond = cond
        @stmts = stmts
    end

    def compile(indent = "")
        @cond = @cond.compile if not @cond.kind_of?(String)

        @stmts = compile_stmts(@stmts, indent + "\t")

        "while (" + @cond + "):\n" + indent + @stmts 
    end
end

class Func < General
    def initialize(name, stmts, var, args = [])
        @name = name
        @stmts = stmts
        @var = var
        @args = args
    end

    def compile(indent = "")
        if not @args.empty?
            @args = @args.map{|arg| 
                    if not arg.kind_of?(String)
                        arg.compile
                    else
                        arg
                    end
                }
        end

        if @var.kind_of?(Mathop) or @var.kind_of?(VarExpr)
            @var = @var.compile
        end


        @stmts = compile_stmts(@stmts, indent + "\t")
        "def " + @name + "(" + @args*", " + "):\n" + @stmts + "\n\t" + indent + "return " + @var.to_s
    end
end

class Funccall < General
    def initialize(name, args = [])
        @name = name
        @args = args
    end

    def compile
        if not @args.empty?
            @args = @args.map{|arg| 
                    if arg.kind_of?(Funccall) or arg.kind_of?(Mathop)
                        arg.compile
                    else
                        arg
                    end
                }
        end

        @name + "(" + @args*", " + ")"
    end
end

class Mathop < General
    def initialize(vl, op, hl)
        @vl = vl
        @op = op
        @hl = hl
    end

    def compile
        if @hl.kind_of?(Mathop)
            @hl = @hl.compile 
        end
        @vl.to_s + @op + @hl.to_s
    end
end

class Change_var
    def initialize(name, value)
        @name = name
        @value = value
    end

    def compile(indent = "")
        if @value.kind_of?(Mathop)
            @value = @value.compile
        elsif @value.kind_of?(Input)
            @value = @value.compile
        elsif @value.kind_of?(VarExpr)
            @value = @value.compile
        end

        if not DeclaredVars.is_declared(@name)
            puts "Variable " + @name + " is not declared."
            exit()
        end
        
        if ["sant", "falskt"].include?(@value) && DeclaredVars.get_type(@name)=="sf"
            return (indent + @name + " = " + @value)

        elsif (@value.to_s =~ /(\d+|\.(\d+)|\+|\-|\*|\/)+/ ? true : false) &&
                DeclaredVars.get_type(@name)=="nmr"
            return (indent + @name + " = " + @value.to_s)

        elsif DeclaredVars.get_type(@name) == "str"
            return (indent + @name + " = " + @value)

        else
            puts "Variable " + @name + " is the wrong type."
            exit()
        end
    end
end

class DeclaredVars
    @@db = {}


    def self.is_declared(name)
        @@db.has_key?(name)
    end

    def self.get_type(name)
        @@db[name]
    end

    def self.declare(name, type)
        @@db[name] = type
    end
end
 


