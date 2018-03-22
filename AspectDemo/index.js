
runPositionAfter('ViewController', { read : function(aa) {

  log(aa + '  this is  ' + ViewController.name)
  ViewController.name = 'wodemingiz'
  return '返回'
}});

// runPositionBefore('ViewController', 'read:');
