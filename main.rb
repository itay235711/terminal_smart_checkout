#!/usr/bin/ruby
require 'tty-prompt'
require 'tty-command'
require 'colorize'

PROMPT = TTY::Prompt.new(interrupt: :exit)

def main
    local_branches = parse_git_branch_command_output(`git branch --sort=-committerdate`)
    remote_branches = parse_git_branch_command_output(`git branch -r`)
    selected_branch = ask_user_for_selected_branch(local_branches, remote_branches)

    branch_name =
        if selected_branch.is_remote?
            # Let get to the trick - it will create a local branch for the remote one for us
            remove_remote_prefix(selected_branch.name)
        else
            selected_branch.name
        end

    pull_aswell =
        if selected_branch.is_remote?
            false
        else
            PROMPT.yes?('do you want to pull as well?') {|q| q.default true}
        end

    smart_checkout(branch_name, pull_aswell)
end

def ask_user_for_selected_branch(local_branches, remote_branches)
    local_branches_choises = local_branches.map do |branch|
        { name: branch, value: GitBranch.new(branch, false) }
    end

    remote_branches_choises = remote_branches.reject do |branch|
        corsponding_local_branch = remove_remote_prefix(branch)
        local_branches.include? corsponding_local_branch
    end.map do |branch|
        { name: branch, value: GitBranch.new(branch, true) }
    end

    all_choises = local_branches_choises + remote_branches_choises
    print_current_branch()
    selected_branch = PROMPT.select(
        "select a branch to switch too",
        all_choises,
        filter: true,
        per_page: 10
    )
    selected_branch
end

def remove_remote_prefix(branch_name)
    branch_name.split('/')[-1]
end

def print_current_branch
    current_branch = `git rev-parse --abbrev-ref HEAD`.strip
    puts "you are currently on branch #{current_branch.magenta}"
end

def parse_git_branch_command_output(command_output)
    command_output.split("\n").map do |branch_line|
        branch_line.gsub('*', '').strip
    end
end

def smart_checkout(branch_name, pull_aswell)
    puts "smart checking out #{branch_name}"

    run_system_command_with_colored_output('git stash')
    run_system_command_with_colored_output("git checkout #{branch_name}")
    run_system_command_with_colored_output("git pull") if pull_aswell
    run_system_command_with_colored_output('git stash pop')
end

def run_system_command_with_colored_output(command)
    cmd = TTY::Command.new(pty: true, verbose: false)
    splitted_command = command.split(' ')

    cmd.run(*splitted_command)
end

class GitBranch
    def initialize(name, is_remote)
        @name = name
        @is_remote = is_remote
    end

    attr_reader :name
    attr_reader :is_remote; alias_method :is_remote?, :is_remote
end

main
