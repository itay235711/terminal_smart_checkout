#!/usr/bin/ruby
require 'tty-prompt'
require 'tty-command'
require 'colorize'

PROMPT = TTY::Prompt.new(interrupt: :exit)

def main
    current_branch = `git rev-parse --abbrev-ref HEAD`.strip

    local_branches = parse_git_branch_command_output(`git branch --sort=-committerdate`)
    remote_branches = parse_git_branch_command_output(`git branch -r`)

    selected_branch = ask_user_for_selected_branch(local_branches, remote_branches, current_branch)

    branch_name =
        if selected_branch.is_remote?
            # Let git to the trick - it will create a local branch for the remote one for us
            remove_remote_prefix(selected_branch.name)
        else
            selected_branch.name
        end

    post_checkout_operations = ask_user_which_post_checkout_operations_to_perform()
    should_run_update_sh = ask_user_if_should_run_main_update_sh_script()
    post_checkout_operations[:should_run_update_sh] = should_run_update_sh

    begin
        smart_checkout(branch_name, post_checkout_operations)
        puts "SUCCEEDED".black.on_green
    rescue
        puts "FAILED".on_red
    end
end

def ask_user_for_selected_branch(local_branches, remote_branches, current_branch)
    local_branches_choises = local_branches.map do |branch|
        foramtted_choice = { name: branch, value: GitBranch.new(branch, false) }
        if branch == current_branch
            foramtted_choice[:disabled] = '(current branch)'.magenta
            foramtted_choice[:name] = foramtted_choice[:name].magenta
        end
        foramtted_choice
    end

    remote_branches_choises = remote_branches.reject do |branch|
        corsponding_local_branch = remove_remote_prefix(branch)
        local_branches.include? corsponding_local_branch
    end.map do |branch|
        { name: branch, value: GitBranch.new(branch, true) }
    end

    all_choises = local_branches_choises + remote_branches_choises
    selected_branch = PROMPT.select(
        "select a branch to switch too",
        all_choises,
        filter: true,
        per_page: 10
    )
    selected_branch
end

def ask_user_which_post_checkout_operations_to_perform()
    PROMPT.select('do you want to pull / run migrations as well?', [
        { name: 'do nothing', value: { perform_pull: false, perform_migrations: false, perform_rebase_onto_origin_master: false } },
        { name: 'pull and run migrations', value: { perform_pull: true, perform_migrations: true, perform_rebase_onto_origin_master: false } },
        { name: "pull only", value: { perform_pull: true, perform_migrations: false, perform_rebase_onto_origin_master: false } },
        { name: 'pull, run migrations and rebase onto origin/master', value: { perform_pull: true, perform_migrations: true, perform_rebase_onto_origin_master: true } },
        { name: "pull and rebase onto origin/master", value: { perform_pull: true, perform_migrations: false, perform_rebase_onto_origin_master: true } },
        { name: "rebase onto origin/master only", value: { perform_pull: false, perform_migrations: false, perform_rebase_onto_origin_master: true } },
        { name: "run migrations only", value: { perform_pull: false, perform_migrations: true, perform_rebase_onto_origin_master: false } }
    ], per_page: 10)
end

def ask_user_if_should_run_main_update_sh_script()
    PROMPT.yes?('do you want to run ./update_server_only_plus_migrations.sh?', value: 'n')
end

def remove_remote_prefix(branch_name)
    branch_name.split('/')[-1]
end

def parse_git_branch_command_output(command_output)
    command_output.split("\n").map do |branch_line|
        branch_line.gsub('*', '').strip
    end
end

def smart_checkout(branch_name, post_checkout_operations)
    puts "smart checking out #{branch_name}"

    git_wip_files_str = `git status -s`
    uncomitted_changes_exist = git_wip_files_str != ''

    if uncomitted_changes_exist
        puts "### found uncomitted changes on current branch, stashing and unstashing them after checkout ###"
        run_system_command_with_colored_output('git stash')
    end

    begin
        run_system_command_with_colored_output("git checkout #{branch_name}")

        # because I fucked up
        begin
            run_system_command_with_colored_output("git branch -u origin/#{branch_name}")
        rescue
            puts '*** WARANNING! git branch -u origin/#{branch_name} failed! (but it was rescued) ***'
        end

        run_system_command_with_colored_output("git pull") if post_checkout_operations[:perform_pull]
        run_system_command_with_colored_output("./migrator.py migrate", 'migrations') if post_checkout_operations[:perform_migrations]
        run_system_command_with_colored_output("git rebase origin/master") if post_checkout_operations[:perform_rebase_onto_origin_master]
        if post_checkout_operations[:should_run_update_sh]
            run_system_command_with_colored_output("./scripts/update_server_only_plus_migrations.sh")
            run_system_command_with_colored_output("git reset --hard HEAD") # we don't need the shit left over update.sh
        end
    ensure
        if uncomitted_changes_exist
            run_system_command_with_colored_output('git stash pop')
        end
    end
end

def run_system_command_with_colored_output(command, specific_inner_working_directory=nil)
    cmd = TTY::Command.new(pty: true, verbose: false)
    splitted_command = command.split(' ')

    unless specific_inner_working_directory
        cmd.run(*splitted_command)
    else
        previous_dir = Dir.pwd
        puts "File.join(previous_dir, specific_inner_working_directory): #{File.join(previous_dir, specific_inner_working_directory)}"
        Dir.chdir(File.join(previous_dir, specific_inner_working_directory))

        cmd.run(*splitted_command)

        Dir.chdir(previous_dir)
    end
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
