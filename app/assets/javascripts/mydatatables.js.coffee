jQuery ->
  $("#datatable").dataTable {}

jQuery ->
  $("#datatable_all").dataTable {
    paging: false
  }

jQuery ->
  $("#datatable_with_item_options").dataTable {
    paging: false
    order: [[1, 'asc']]
    columnDefs: [
      {
        orderable: false,
        targets: 0
      }
    ]
  }

# These seem to be unused at this point.

jQuery ->
  $("#datatable_denovo").dataTable {paging: false}

jQuery ->
  $("#datatable_autosomal").dataTable {paging: false}

jQuery ->
  $("#datatable_xlinked").dataTable {paging: false}

jQuery ->
  $("#datatable_compound").dataTable {paging: false}

jQuery ->
  $("#datatable_dominant").dataTable {paging: false}