class SubjectMeasure

  # see: http://guides.rubyonrails.org/active_model_basics.html
  include ActiveModel::Model

  def self.measures_table
    search_config = Rails.configuration.x.query['db6']
    @@table = "`#{search_config['project_id']}.#{search_config['tables']['subject_measures']}`"
  end

  def self.tests_table
    search_config = Rails.configuration.x.query['db6']
    @@table = "`#{search_config['project_id']}.#{search_config['tables']['tests']}`"
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
SELECT *
FROM results
EOL

    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| SubjectMeasure.new(record)}
  end

  # getter/setter methods for result columns
  attr_accessor *attrs

end
