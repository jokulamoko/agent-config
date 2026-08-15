# Friendly entry point for jobctl. Run `make help` to list targets.
# Pass JOB=<name> to target a single job; omit it for "all" where it applies.
#
#   make list                 # every job + whether it is loaded
#   make start JOB=sentinel    # load one job on its schedule
#   make start                 # load all jobs
#   make stop  JOB=sentinel    # unload + remove one job
#   make run   JOB=sentinel    # force one run now (testing)
#   make tail  JOB=sentinel    # follow that job's logs

JOBCTL := bin/jobctl
JOB ?=

.PHONY: help list status start stop run tail

help:        ## Show this help
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sort \
		| awk -F':.*##' '{printf "  \033[1m%-9s\033[0m %s\n", $$1, $$2}'

list:        ## List every job and its current state
	@$(JOBCTL) list

status:      ## Full launchd state for a job: make status JOB=sentinel (none = list)
	@$(JOBCTL) status $(JOB)

start:       ## Start a job on its schedule: make start JOB=sentinel (none = all)
	@$(JOBCTL) start $(JOB)

stop:        ## Stop a job: make stop JOB=sentinel (none = all)
	@$(JOBCTL) stop $(JOB)

run:         ## Force one run now for testing: make run JOB=sentinel
	@$(JOBCTL) run $(JOB)

tail:        ## Follow a job's logs: make tail JOB=sentinel
	@$(JOBCTL) tail $(JOB)

