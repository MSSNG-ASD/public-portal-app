class SubjectMeasure

  # see: http://guides.rubyonrails.org/active_model_basics.html
  include ActiveModel::Model

  def self.measures_table
    @@measures_table = "`#{Rails.configuration.x.query['dataset_id']}.#{Rails.configuration.x.query['subject_measures']}`"
  end

  def self.tests_table
    @@tests_table = "`#{Rails.configuration.x.query['dataset_id']}.#{Rails.configuration.x.query['tests']}`"
  end

  def self.attrs
    Rails.configuration.x.query['subject_measure_attrs']
  end

  def self.find(user, id)
    sql  = <<EOL
#standardSQL
WITH
measures as (
SELECT
indexid,
code,
testdate,
measure
FROM
#{measures_table}
WHERE
indexid = '#{id}'
),
tests as (
SELECT
code,
relevance,
test,
question,
legend
FROM
#{tests_table}
),
results as (
SELECT
measures.testdate,
measures.measure,
tests.relevance,
tests.test,
tests.question,
tests.legend
FROM
measures
JOIN
tests
ON
measures.code = tests.code
)
SELECT
*
FROM
results
EOL

    BigQuery.new(user.credentials).exec_query(sql).map {|record| SubjectMeasure.new(record)}
  end

  # getter/setter methods for result columns
  attr_accessor *attrs

end
