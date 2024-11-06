update message_template
set message =
 "Hey {{customer_name}}, just a quick note to let you know I'm running about {{delay_period}} behind. Sorry for the delay.",
 title = 'Running Late'
where title = 
 "Running Late - Short Delay";

delete message_template
where title = 'Running Late - Traffic';

delete message_template
where title = 'Running Late - Previous Job Overrun';


delete message_template
where title = 'Running Late - Weather Conditions';

