$(document).ready(function () {

  if($('#igv-container').length > 0){
    var div = $("#igv-container")[0],
      options = {
        oauthToken: $('#igv-container').data('token'),
        showKaryo: false,
        showNavigation: true,
        fastaURL: "//dn7ywbm9isq8j.cloudfront.net/genomes/seq/1kg_v37/human_g1k_v37_decoy.fasta",
        cytobandURL: "//dn7ywbm9isq8j.cloudfront.net/genomes/seq/b37/b37_cytoband.txt",
        locus: $('#igv-container').data('locus'),
        tracks: $('#igv-container').data('tracks')
      };
    igv.createBrowser(div, options);
  };

});
