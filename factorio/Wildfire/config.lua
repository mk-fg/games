local conf = {}

conf.spark_interval = 24 * 60 * 60
conf.spark_interval_jitter = 22 * 60 * 60

conf.check_interval = 3 * 60
conf.check_radius = 20 * 32
conf.check_limit = 10

conf.min_green_trees = 500
conf.max_dead_trees = 700
conf.green_dead_balance = 20


function conf.update_from_settings()
	conf.spark_interval = settings.startup['wf-spark-interval'].value
	conf.spark_interval_jitter = settings.startup['wf-spark-interval-jitter'].value

	conf.check_interval = settings.startup['wf-check-interval'].value
	conf.check_limit = settings.startup['wf-check-radius'].value
	conf.check_radius = settings.startup['wf-check-limit'].value

	conf.min_green_trees = settings.startup['wf-min-green-trees'].value
	conf.max_dead_trees = settings.startup['wf-max-dead-trees'].value
	conf.green_dead_balance = settings.startup['wf-green-dead-balance'].value
end

return conf
