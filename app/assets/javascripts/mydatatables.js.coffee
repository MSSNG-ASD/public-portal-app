jQuery ->
  $("#datatable").dataTable {
    scrollX: true,
    searching: false,
  }

jQuery ->
  $("#datatable_all").dataTable {
    paging: false,
    scrollX: true,
    searching: false,
  }

jQuery ->
  $("#datatable_with_item_options").dataTable {
    paging: false,
    scrollX: true,
    searching: false,
    order: [[1, 'asc']],
    columnDefs: [
      {
        orderable: false,
        targets: 0
      }
    ]
  }

# These seem to be unused at this point.

jQuery ->
  $("#datatable_denovo").dataTable {paging: false, searching: false}

jQuery ->
  $("#datatable_autosomal").dataTable {paging: false, searching: false}

jQuery ->
  $("#datatable_xlinked").dataTable {paging: false, searching: false}

jQuery ->
  $("#datatable_compound").dataTable {paging: false, searching: false}

jQuery ->
  $("#datatable_dominant").dataTable {paging: false, searching: false}