
        anno.setAuthInfo({
            id: 'Cutie',
            displayName: 'Cutie'
        });

        anno.on('selectAnnotation', function (a, shape) {
            console.log('selected');
        });

        anno.on('cancelSelected', function (a) {
            console.log('cancel');
        });

        anno.on('changeSelected', function (selected, previous) {
            console.log('changed from', previous, 'to', selected);
        });

        anno.on('createAnnotation', function (annotation) {
            console.log('created', annotation);
        });

        anno.on('updateAnnotation', function (annotation, previous) {
            console.log('updated', previous, 'with', annotation);
        });

        anno.on('clickAnnotation', function (annotation, shape) {
            console.log('clicked', annotation);
        });

        anno.on('deleteAnnotation', function (annotation) {
            console.log('deleted', annotation);
        });

        anno.on('mouseEnterAnnotation', function (annotation) {
            console.log('enter', annotation);
        });

        anno.on('mouseLeaveAnnotation', function (annotation) {
            console.log('leave', annotation);
        });
