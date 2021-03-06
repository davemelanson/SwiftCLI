//
//  CLI.swift
//  SwiftCLI
//
//  Created by Jake Heiser on 7/20/14.
//  Copyright (c) 2014 jakeheis. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public class CLI {
    
    public let name: String
    public let version: String?
    public var description: String?
    public var commands: [Routable]
    
    public var helpMessageGenerator: HelpMessageGenerator = DefaultHelpMessageGenerator()
    public var argumentListManipulators: [ArgumentListManipulator] = [CommandAliaser(), OptionSplitter()]
    public var router: Router = DefaultRouter()
    public var optionRecognizer: OptionRecognizer = DefaultOptionRecognizer()
    public var parameterFiller: ParameterFiller = DefaultParameterFiller()
    
    public init(name: String, version: String? = nil, commands: [Routable]) {
        self.name = name
        self.version = version
        self.commands = commands
        
        self.commands.append(HelpCommand(cli: self))
        if let version = version {
            self.commands.append(VersionCommand(version: version))
        }
    }
    
    /// Generates shell completions for the cli's commands
    ///
    /// - Parameter shell: the type of shell for which to generate completions
    /// - Returns: a generator
    public func createCompletionGenerator(for shell: Shell) -> CompletionGenerator {
        if shell == .bash {
            fatalError("Bash completions not yet supported")
        }
        return ZshCompletionGenerator(cli: self)
    }
    
    /// Kicks off the entire CLI process, routing to and executing the command specified by the passed arguments.
    /// Uses the arguments passed in the command line. Exits the program upon completion.
    ///
    /// - SeeAlso: `debugGoWithArgumentString()` when debugging
    /// - Returns: Never
    public func goAndExit() -> Never {
        let result = go()
        exit(result)
    }
    
    /// Kicks off the entire CLI process, routing to and executing the command specified by the passed arguments.
    /// Uses the arguments passed in the command line.
    ///
    /// - SeeAlso: `debugGoWithArgumentString()` when debugging
    /// - Returns: a CLIResult (Int32) representing the success of the CLI in routing to and executing the correct
    /// command. Usually should be passed to `exit(result)`
    public func go() -> Int32 {
        return go(with: ArgumentList())
    }
    
    /// Kicks off the entire CLI process, routing to and executing the command specified by the passed arguments.
    /// Uses the argument string passed to this function.
    ///
    /// - SeeAlso: `go()` when running from the command line
    /// - Parameter argumentString: the arguments to use when running the CLI
    /// - Returns: a CLIResult (Int) representing the success of the CLI in routing to and executing the correct
    /// command. Usually should be passed to `exit(result)`
    public func debugGo(with argumentString: String) -> Int32 {
        print("[Debug Mode]")
        return go(with: ArgumentList(argumentString: argumentString))
    }
    
    // MARK: - Privates
    
    private func go(with arguments: ArgumentList) -> Int32 {
        argumentListManipulators.forEach { $0.manipulate(arguments: arguments) }
        
        var exitStatus: Int32 = 0
        
        do {
            // Step 1: route
            let command = try routeCommand(arguments: arguments)
            
            // Step 2: recognize options
            try recognizeOptions(of: command, in: arguments)
            if DefaultGlobalOptions.help.value == true {
                print(helpMessageGenerator.generateUsageStatement(for: command, cliName: name))
                return exitStatus
            }
            
            // Step 3: fill parameters
            try fillParameters(of: command, with: arguments)
            
            // Step 4: execute
            try command.execute()
        } catch let error as ProcessError {
            if let message = error.message {
                printError(message)
            }
            exitStatus = Int32(error.exitStatus)
        } catch let error {
            printError("An error occurred: \(error.localizedDescription)")
            exitStatus = 1
        }
        
        return exitStatus
    }
    
    private func routeCommand(arguments: ArgumentList) throws -> Command {
        let routeResult = router.route(routables: commands, arguments: arguments)
        
        switch routeResult {
        case let .success(command):
            return command
        case let .failure(partialPath: partialPath, group: group, attempted: attempted):
            if let attempted = attempted {
                printError("\nCommand \"\(attempted)\" not found")
            }
            let description: String?
            let routables: [Routable]
            if let group = group {
                description = attempted == nil ? group.shortDescription : nil
                routables = group.children
            } else {
                description = attempted == nil ? self.description : nil
                routables = commands
            }
            let list = helpMessageGenerator.generateCommandList(
                prefix: ([name] + partialPath).joined(separator: " "),
                description: description,
                routables: routables
            )
            print(list)
            throw CLI.Error()
        }
    }
    
    private func recognizeOptions(of command: Command, in arguments: ArgumentList) throws {
        if command is HelpCommand {
            return
        }
        
        do {
            try optionRecognizer.recognizeOptions(of: command, in: arguments)
        } catch let error as OptionRecognizerError {
            let message = helpMessageGenerator.generateMisusedOptionsStatement(for: command, error: error, cliName: name)
            throw CLI.Error(message: message)
        }
    }
    
    private func fillParameters(of command: Command, with arguments: ArgumentList) throws {
        if command is HelpCommand {
            return
        }
        
        do {
            try parameterFiller.fillParameters(of: command, with: arguments)
        } catch let error as CLI.Error {
            if let message = error.message {
                printError(message)
            }
            printError("Usage: \(name) \(command.usage)")
            throw CLI.Error(exitStatus: error.exitStatus)
        }
    }
    
}
